-- ============================================================================
-- Migration 00047: stock_place_multi_order — support MANUAL item lines.
--
-- HOD can now place an order with a brand-new item typed directly (no
-- pre-existing catalog entry). When a line has no item_id, the RPC creates
-- the stock item first (name / uom / code), then inserts the order row with
-- the new item's id. Existing catalog picks keep working unchanged.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.stock_place_multi_order(
  p_order_no text,
  p_site_id text,
  p_stock_point_id text,
  p_stock_point_name text,
  p_items jsonb,
  p_thavvu_point_id text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_item jsonb;
  v_email text := auth.jwt() ->> 'email';
  v_batch text;
  v_item_id uuid;
  v_item_code text;
  v_count int := 0;
BEGIN
  IF p_order_no IS NULL OR trim(p_order_no) = '' THEN
    RAISE EXCEPTION 'Order number is required';
  END IF;
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order requires at least one item';
  END IF;
  IF p_stock_point_id IS NULL OR trim(p_stock_point_id) = '' THEN
    RAISE EXCEPTION 'Stock point is required';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    IF COALESCE(v_item ->> 'item_name', '') = '' THEN
      RAISE EXCEPTION 'Every order line needs an item name';
    END IF;

    -- Resolve the item by id, or create it from the typed name (manual entry).
    IF COALESCE(v_item ->> 'item_id', '') <> '' THEN
      SELECT id INTO v_item_id
        FROM public.stock_items
        WHERE id = (v_item ->> 'item_id')::uuid
        LIMIT 1;
      IF v_item_id IS NULL THEN
        RAISE EXCEPTION 'Item % not found in catalog', v_item ->> 'item_id';
      END IF;
      SELECT COALESCE(NULLIF(code, ''), NULLIF(item_code, ''))
        INTO v_item_code
        FROM public.stock_items WHERE id = v_item_id;
    ELSE
      SELECT id, COALESCE(NULLIF(code, ''), NULLIF(item_code, ''))
        INTO v_item_id, v_item_code
        FROM public.stock_items
        WHERE lower(COALESCE(name, item_name, '')) = lower(trim(v_item ->> 'item_name'))
        LIMIT 1;
      IF v_item_id IS NULL THEN
        v_item_code := COALESCE(NULLIF(trim(v_item ->> 'item_code'), ''),
          'ORD-' || upper(left(regexp_replace(
            v_item ->> 'item_name', '[^a-zA-Z0-9]+', '', 'g'), 10)));
        INSERT INTO public.stock_items
          (id, code, item_code, name, item_name, group_name, category, uom,
           primary_uom, batch_required, is_active)
        VALUES
          (gen_random_uuid()::text, v_item_code, v_item_code,
           trim(v_item ->> 'item_name'), trim(v_item ->> 'item_name'),
           'HOD Order', 'Ordered', COALESCE(NULLIF(v_item ->> 'unit', ''), 'units'),
           COALESCE(NULLIF(v_item ->> 'unit', ''), 'units'), true, true)
        RETURNING id INTO v_item_id;
      END IF;
    END IF;

    v_batch := COALESCE(NULLIF(trim(v_item ->> 'batch'), ''),
      'B-' || upper(COALESCE(NULLIF(v_item ->> 'item_code', ''), v_item_code,
        regexp_replace(v_item ->> 'item_name', '[^a-zA-Z0-9]+', '', 'g'))) ||
      '-' || to_char(now(), 'YYYY'));

    INSERT INTO public.stock_orders
      (order_no, site_id, stock_point_id, stock_point_name, thavvu_point_id,
       item_id, item_name, batch, quantity, unit, status, notes, placed_by,
       created_at, updated_at)
    VALUES
      (trim(p_order_no), p_site_id, p_stock_point_id, p_stock_point_name,
       p_thavvu_point_id,
       v_item_id,
       COALESCE(v_item ->> 'item_name', 'Item'),
       v_batch,
       COALESCE((v_item ->> 'quantity')::numeric, 0),
       COALESCE(NULLIF(v_item ->> 'unit', ''), 'units'),
       'placed',
       COALESCE(NULLIF(trim(v_item ->> 'notes'), ''), p_notes),
       v_email,
       now(), now());
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'count', v_count, 'order_no', trim(p_order_no));
END $$;
