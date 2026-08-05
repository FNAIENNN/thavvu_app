-- ============================================================================
-- Migration 00042: Multi-item stock orders.
--
-- HOD places ONE order containing multiple items. The order is stored as
-- stock_orders rows sharing the same order_no (a group). Adds receive
-- tracking columns and an atomic SECURITY DEFINER RPC so all lines of an
-- order are placed together and can later be moved into GIN as one bill.
-- ============================================================================

ALTER TABLE public.stock_orders ADD COLUMN IF NOT EXISTS received_at timestamptz;
ALTER TABLE public.stock_orders ADD COLUMN IF NOT EXISTS received_by text;

CREATE INDEX IF NOT EXISTS idx_stock_orders_order_no ON public.stock_orders(order_no);

-- ---------------------------------------------------------------------------
-- stock_place_multi_order — insert every line of an order atomically
-- ---------------------------------------------------------------------------
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
    IF COALESCE(v_item ->> 'item_id', '') = '' THEN
      RAISE EXCEPTION 'Every order line needs an item';
    END IF;

    v_batch := COALESCE(NULLIF(trim(v_item ->> 'batch'), ''),
      'B-' || upper(COALESCE(NULLIF(v_item ->> 'item_code', ''),
        regexp_replace(v_item ->> 'item_name', '[^a-zA-Z0-9]+', '', 'g'))) ||
      '-' || to_char(now(), 'YYYY'));

    INSERT INTO public.stock_orders
      (order_no, site_id, stock_point_id, stock_point_name, thavvu_point_id,
       item_id, item_name, batch, quantity, unit, status, notes, placed_by,
       created_at, updated_at)
    VALUES
      (trim(p_order_no), p_site_id, p_stock_point_id, p_stock_point_name,
       p_thavvu_point_id,
       (v_item ->> 'item_id')::uuid,
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
