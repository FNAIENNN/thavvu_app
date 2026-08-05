-- ============================================================================
-- Migration 00040: gin_add_to_stock — satisfy stock_movements NOT NULL cols.
--
-- The live legacy stock_movements table declares from_stock_point_id NOT
-- NULL. For goods-inward movements we record the receiving Thavvu Point as
-- the source so the audit row satisfies the constraint (matches how the app
-- writes transfer/consumption movements).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.gin_add_to_stock(p_bill_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_bill public.gin_bills%ROWTYPE;
  v_item RECORD;
  v_item_id text;
  v_item_code text;
  v_balance_id text;
  v_email text := auth.jwt() ->> 'email';
  v_added int := 0;
  v_skipped text[] := '{}'::text[];
BEGIN
  SELECT * INTO v_bill FROM public.gin_bills WHERE id = p_bill_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GIN bill not found';
  END IF;
  IF v_bill.status = 'added_to_stock' THEN
    RETURN jsonb_build_object('ok', true, 'added', 0, 'status', 'already_added');
  END IF;
  IF v_bill.hod_status <> 'approved' THEN
    RAISE EXCEPTION 'GIN is not approved by HOD';
  END IF;

  FOR v_item IN SELECT * FROM public.gin_bill_items WHERE gin_bill_id = p_bill_id LOOP
    IF v_item.received_qty IS NULL OR v_item.received_qty <= 0 THEN
      v_skipped := array_append(v_skipped, v_item.item_name || ' (0 received)');
      CONTINUE;
    END IF;

    SELECT id, COALESCE(NULLIF(code, ''), NULLIF(item_code, ''))
      INTO v_item_id, v_item_code
      FROM public.stock_items
      WHERE lower(COALESCE(name, item_name, '')) = lower(v_item.item_name)
      LIMIT 1;

    IF v_item_id IS NULL THEN
      v_item_code := 'GIN-' || upper(left(regexp_replace(
          v_item.item_name, '[^a-zA-Z0-9]+', '', 'g'), 12));
      INSERT INTO public.stock_items
        (id, code, item_code, name, item_name, group_name, category, uom,
         primary_uom, batch_required, is_active)
      VALUES
        (gen_random_uuid()::text, v_item_code, v_item_code, v_item.item_name,
         v_item.item_name, 'GIN Received', 'GIN', COALESCE(v_item.uom, 'units'),
         COALESCE(v_item.uom, 'units'), false, true)
      RETURNING id INTO v_item_id;
    END IF;

    SELECT id INTO v_balance_id
      FROM public.stock_batch_balances
      WHERE item_id = v_item_id
        AND stock_point_id = v_bill.thavvu_point_id
        AND batch_id = v_bill.gin_no
      LIMIT 1;

    IF v_balance_id IS NULL THEN
      INSERT INTO public.stock_batch_balances
        (id, item_id, item_name, item_code, stock_point_id, stock_point_name,
         location, batch_id, batch_code, available_qty, loose_qty)
      VALUES
        (gen_random_uuid()::text, v_item_id, v_item.item_name, v_item_code,
         v_bill.thavvu_point_id, v_bill.thavvu_point_name,
         v_bill.thavvu_point_name, v_bill.gin_no, v_bill.gin_no,
         v_item.received_qty, 0)
      RETURNING id INTO v_balance_id;
    ELSE
      UPDATE public.stock_batch_balances
        SET available_qty = available_qty + v_item.received_qty,
            item_name = v_item.item_name,
            item_code = COALESCE(item_code, v_item_code),
            updated_at = now()
        WHERE id = v_balance_id;
    END IF;

    INSERT INTO public.stock_movements
      (reference_id, movement_type, item_id, batch_balance_id, batch_id,
       from_stock_point_id, to_stock_point_id, quantity, loose_quantity,
       reason, created_at)
    VALUES
      (v_bill.gin_no, 'gin', v_item_id, v_balance_id, v_bill.gin_no,
       v_bill.thavvu_point_id, v_bill.thavvu_point_id,
       v_item.received_qty, 0,
       'Goods inward — ' || v_item.item_name ||
         ' (Bill ' || v_bill.bill_number || ')', now());

    v_added := v_added + 1;
  END LOOP;

  UPDATE public.gin_bills
    SET status = 'added_to_stock',
        added_to_stock_by = v_email,
        added_to_stock_at = now(),
        updated_at = now()
    WHERE id = p_bill_id;

  RETURN jsonb_build_object('ok', true, 'added', v_added,
                            'skipped', to_jsonb(v_skipped), 'status', 'added_to_stock');
END $$;
