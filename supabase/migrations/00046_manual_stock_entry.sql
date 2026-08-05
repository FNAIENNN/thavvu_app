-- ============================================================================
-- Migration 00046: Clean stock slate + manual stock entry.
--
-- 1. Removes EVERY demo/transactional stock row so the app starts with a
--    clean slate:
--      * stock_batch_balances  (all seeded demo balances)
--      * stock_movements       (all audit rows)
--      * stock_orders          (all demo orders)
--      * gin_bills / items / documents (demo GIN bills; cascade)
--    The stock_items master catalog is KEPT — it is reference data needed
--    by order placement and manual entry. New stock only enters through
--    manual entry or approved GINs, and persists long-term in Supabase.
--
-- 2. stock_manual_entry RPC — supervisor manually adds stock at a Thavvu
--    Point. Resolves or creates the stock item, upserts the batch balance
--    and writes a 'manual_in' movement. Atomic and idempotent on batch.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Clean slate
-- ---------------------------------------------------------------------------
DELETE FROM public.stock_movements;
DELETE FROM public.stock_batch_balances;
DELETE FROM public.stock_orders;
DELETE FROM public.gin_bills; -- cascades gin_bill_items + gin_bill_documents

-- ---------------------------------------------------------------------------
-- 2. stock_manual_entry
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.stock_manual_entry(
  p_item_name text,
  p_quantity numeric,
  p_thavvu_point_id text,
  p_thavvu_point_name text,
  p_uom text DEFAULT 'units',
  p_batch text DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_item_code text DEFAULT NULL,
  p_site_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_item_id text;
  v_item_code text;
  v_batch text;
  v_balance_id text;
  v_email text := auth.jwt() ->> 'email';
BEGIN
  IF p_item_name IS NULL OR trim(p_item_name) = '' THEN
    RAISE EXCEPTION 'Item name is required';
  END IF;
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be greater than zero';
  END IF;
  IF p_thavvu_point_id IS NULL OR trim(p_thavvu_point_id) = '' THEN
    RAISE EXCEPTION 'Thavvu Point is required';
  END IF;

  v_batch := COALESCE(NULLIF(trim(p_batch), ''),
    'B-' || upper(left(regexp_replace(p_item_name, '[^a-zA-Z0-9]+', '', 'g'), 10)) ||
    '-' || to_char(now(), 'YYYY'));

  -- Resolve the master stock item by name, or create a lightweight entry.
  SELECT id, COALESCE(NULLIF(code, ''), NULLIF(item_code, ''))
    INTO v_item_id, v_item_code
    FROM public.stock_items
    WHERE lower(COALESCE(name, item_name, '')) = lower(trim(p_item_name))
    LIMIT 1;

  IF v_item_id IS NULL THEN
    v_item_code := COALESCE(NULLIF(trim(p_item_code), ''),
      'MAN-' || upper(left(regexp_replace(p_item_name, '[^a-zA-Z0-9]+', '', 'g'), 10)));
    INSERT INTO public.stock_items
      (id, code, item_code, name, item_name, group_name, category, uom,
       primary_uom, batch_required, is_active)
    VALUES
      (gen_random_uuid()::text, v_item_code, v_item_code, trim(p_item_name),
       trim(p_item_name), 'Manual Entry', 'Manual', COALESCE(p_uom, 'units'),
       COALESCE(p_uom, 'units'), true, true)
    RETURNING id INTO v_item_id;
  END IF;

  -- Upsert the balance for (item, Thavvu Point, batch).
  SELECT id INTO v_balance_id
    FROM public.stock_batch_balances
    WHERE item_id = v_item_id
      AND stock_point_id = p_thavvu_point_id
      AND batch_id = v_batch
    LIMIT 1;

  IF v_balance_id IS NULL THEN
    INSERT INTO public.stock_batch_balances
      (id, item_id, item_name, item_code, stock_point_id, stock_point_name,
       location, batch_id, batch_code, available_qty, loose_qty)
    VALUES
      (gen_random_uuid()::text, v_item_id, trim(p_item_name), v_item_code,
       p_thavvu_point_id, p_thavvu_point_name, p_thavvu_point_name,
       v_batch, v_batch, p_quantity, 0)
    RETURNING id INTO v_balance_id;
  ELSE
    UPDATE public.stock_batch_balances
      SET available_qty = available_qty + p_quantity,
          item_name = trim(p_item_name),
          item_code = COALESCE(item_code, v_item_code),
          updated_at = now()
      WHERE id = v_balance_id;
  END IF;

  INSERT INTO public.stock_movements
    (reference_id, movement_type, item_id, batch_balance_id, batch_id,
     from_stock_point_id, to_stock_point_id, quantity, loose_quantity,
     reason, created_at)
  VALUES
    ('MAN-' || to_char(now(), 'YYYYMMDD') || '-' ||
       upper(substr(md5(random()::text), 1, 5)),
     'manual_in', v_item_id, v_balance_id, v_batch,
     p_thavvu_point_id, p_thavvu_point_id, p_quantity, 0,
     COALESCE(NULLIF(trim(p_note), ''), 'Manual stock entry'), now());

  RETURN jsonb_build_object('ok', true, 'item_id', v_item_id,
                            'batch', v_batch, 'quantity', p_quantity,
                            'balance_id', v_balance_id);
END $$;
