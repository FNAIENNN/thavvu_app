-- ============================================================================
-- Migration 00043: Order receive -> GIN conversion.
--
-- When the supervisor taps "Received Order" in View Orders, this RPC takes
-- every line of the order group (shared order_no) and creates ONE
-- multi-item GIN bill (gin_bills + gin_bill_items) that flows through the
-- same reconciliation table (Shortage / Extra / OK actions) and the HOD
-- approval queue. The order rows are marked 'received' atomically.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.gin_create_from_order(p_order_no text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_order RECORD;
  v_bill_id uuid;
  v_gin_no text;
  v_email text := auth.jwt() ->> 'email';
  v_thavvu_point_id text;
  v_thavvu_point_name text;
  v_count int := 0;
BEGIN
  IF p_order_no IS NULL OR trim(p_order_no) = '' THEN
    RAISE EXCEPTION 'Order number is required';
  END IF;

  -- Lock every line of the order group; all must still be 'placed'.
  FOR v_order IN
    SELECT * FROM public.stock_orders
    WHERE order_no = trim(p_order_no)
    ORDER BY created_at, id
    FOR UPDATE
  LOOP
    IF v_order.status <> 'placed' THEN
      RAISE EXCEPTION 'Order % is already received (status: %)',
        p_order_no, v_order.status;
    END IF;
    IF v_thavvu_point_id IS NULL THEN
      v_thavvu_point_id := COALESCE(v_order.thavvu_point_id, v_order.stock_point_id);
      v_thavvu_point_name := v_order.stock_point_name;
    END IF;
    v_count := v_count + 1;
  END LOOP;

  IF v_count = 0 THEN
    RAISE EXCEPTION 'Order % not found', p_order_no;
  END IF;

  v_gin_no := 'GIN-' || to_char(now(), 'YYYYMMDD') || '-' ||
    upper(substr(md5(random()::text), 1, 5));

  INSERT INTO public.gin_bills
    (gin_no, bill_number, supplier_name, site_id, thavvu_point_id,
     thavvu_point_name, status, submitted_by, submitted_at, hod_status)
  VALUES
    (v_gin_no, trim(p_order_no), 'HOD Order ' || trim(p_order_no),
     (SELECT site_id FROM public.stock_orders WHERE order_no = trim(p_order_no) LIMIT 1),
     v_thavvu_point_id, v_thavvu_point_name,
     'pending', v_email, now(), 'pending')
  RETURNING id INTO v_bill_id;

  FOR v_order IN
    SELECT * FROM public.stock_orders
    WHERE order_no = trim(p_order_no)
    ORDER BY created_at, id
  LOOP
    INSERT INTO public.gin_bill_items
      (gin_bill_id, item_name, ordered_qty, billed_qty, received_qty, uom,
       action, action_note)
    VALUES
      (v_bill_id, v_order.item_name, v_order.quantity, v_order.quantity,
       v_order.quantity, COALESCE(v_order.unit, 'units'), NULL, NULL);
  END LOOP;

  UPDATE public.stock_orders
    SET status = 'received', received_by = v_email, received_at = now(),
        updated_at = now()
    WHERE order_no = trim(p_order_no);

  RETURN jsonb_build_object('ok', true, 'id', v_bill_id, 'gin_no', v_gin_no,
                            'items', v_count, 'order_no', trim(p_order_no));
END $$;
