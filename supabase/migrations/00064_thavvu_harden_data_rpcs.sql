-- ============================================================================
-- 00064_thavvu_harden_data_rpcs.sql
-- SECURITY DEFINER data RPCs bypass RLS, so they must check tenant isolation
-- themselves. Every GIN / stock RPC now rejects callers whose tenant does not
-- own the target site / point / bill / order.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.gin_submit_bill(p_bill_number text, p_supplier_name text, p_thavvu_point_id text, p_thavvu_point_name text, p_items jsonb, p_gin_no text DEFAULT NULL::text, p_supplier_id text DEFAULT NULL::text, p_site_id text DEFAULT NULL::text, p_bill_date date DEFAULT NULL::date, p_documents jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bill_id uuid;
  v_gin_no text;
  v_item jsonb;
  v_doc jsonb;
  v_email text := auth.jwt() ->> 'email';
BEGIN
  -- TENANT GUARD: only the owning department may operate on this record.
  IF NOT public.is_same_tenant(
        (SELECT tp.hod_id FROM public.thavvu_points tp WHERE tp.id = p_thavvu_point_id)
  ) THEN
    RAISE EXCEPTION 'Forbidden: data does not belong to your department';
  END IF;
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'GIN requires at least one item';
  END IF;
  IF p_bill_number IS NULL OR trim(p_bill_number) = '' THEN
    RAISE EXCEPTION 'Bill number is required';
  END IF;
  IF p_thavvu_point_id IS NULL OR trim(p_thavvu_point_id) = '' THEN
    RAISE EXCEPTION 'Thavvu Point is required';
  END IF;
  IF p_supplier_name IS NULL OR trim(p_supplier_name) = '' THEN
    RAISE EXCEPTION 'Supplier is required';
  END IF;

  v_gin_no := COALESCE(NULLIF(trim(p_gin_no), ''),
    'GIN-' || to_char(now(), 'YYYYMMDD') || '-' ||
      upper(substr(md5(random()::text), 1, 5)));

  INSERT INTO public.gin_bills
    (gin_no, bill_number, supplier_id, supplier_name, site_id,
     thavvu_point_id, thavvu_point_name, bill_date,
     status, submitted_by, submitted_at, hod_status)
  VALUES
    (v_gin_no, trim(p_bill_number), p_supplier_id, trim(p_supplier_name),
     p_site_id, p_thavvu_point_id, trim(p_thavvu_point_name), p_bill_date,
     'pending', v_email, now(), 'pending')
  RETURNING id INTO v_bill_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    INSERT INTO public.gin_bill_items
      (gin_bill_id, item_name, ordered_qty, billed_qty, received_qty,
       uom, action, action_note)
    VALUES
      (v_bill_id,
       COALESCE(NULLIF(v_item ->> 'item_name', ''), 'Item'),
       COALESCE((v_item ->> 'ordered_qty')::numeric, 0),
       COALESCE((v_item ->> 'billed_qty')::numeric, 0),
       COALESCE((v_item ->> 'received_qty')::numeric, 0),
       COALESCE(NULLIF(v_item ->> 'uom', ''), 'units'),
       NULLIF(v_item ->> 'action', ''),
       NULLIF(v_item ->> 'action_note', ''));
  END LOOP;

  FOR v_doc IN SELECT * FROM jsonb_array_elements(COALESCE(p_documents, '[]'::jsonb)) LOOP
    INSERT INTO public.gin_bill_documents
      (gin_bill_id, name, type, storage_path, uploaded_by)
    VALUES
      (v_bill_id,
       COALESCE(NULLIF(v_doc ->> 'name', ''), 'document'),
       COALESCE(NULLIF(v_doc ->> 'type', ''), 'photo'),
       NULLIF(v_doc ->> 'storage_path', ''),
       v_email);
  END LOOP;

  RETURN jsonb_build_object('id', v_bill_id, 'gin_no', v_gin_no,
                            'status', 'pending');
END $function$;

CREATE OR REPLACE FUNCTION public.gin_update_bill(p_bill_id uuid, p_bill_number text, p_supplier_name text, p_thavvu_point_id text, p_thavvu_point_name text, p_items jsonb, p_supplier_id text DEFAULT NULL::text, p_site_id text DEFAULT NULL::text, p_bill_date date DEFAULT NULL::date, p_documents jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bill public.gin_bills%ROWTYPE;
  v_item jsonb;
  v_doc jsonb;
  v_email text := auth.jwt() ->> 'email';
BEGIN
  -- TENANT GUARD: only the owning department may operate on this record.
  IF NOT public.is_same_tenant(
        (SELECT g.hod_id FROM public.gin_bills g WHERE g.id = p_bill_id)
  ) THEN
    RAISE EXCEPTION 'Forbidden: data does not belong to your department';
  END IF;
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'GIN requires at least one item';
  END IF;
  IF p_bill_number IS NULL OR trim(p_bill_number) = '' THEN
    RAISE EXCEPTION 'Bill number is required';
  END IF;

  SELECT * INTO v_bill FROM public.gin_bills WHERE id = p_bill_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GIN bill not found';
  END IF;
  IF v_bill.hod_status = 'approved' OR v_bill.status = 'added_to_stock' THEN
    RAISE EXCEPTION 'Approved GIN cannot be edited';
  END IF;

  UPDATE public.gin_bills
    SET bill_number = trim(p_bill_number),
        supplier_id = p_supplier_id,
        supplier_name = trim(p_supplier_name),
        site_id = p_site_id,
        thavvu_point_id = p_thavvu_point_id,
        thavvu_point_name = trim(p_thavvu_point_name),
        bill_date = p_bill_date,
        status = 'pending',
        submitted_by = v_email,
        submitted_at = now(),
        hod_status = 'pending',
        hod_note = NULL,
        hod_reviewed_by = NULL,
        hod_reviewed_at = NULL,
        updated_at = now()
    WHERE id = p_bill_id;

  DELETE FROM public.gin_bill_items WHERE gin_bill_id = p_bill_id;
  DELETE FROM public.gin_bill_documents WHERE gin_bill_id = p_bill_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    INSERT INTO public.gin_bill_items
      (gin_bill_id, item_name, ordered_qty, billed_qty, received_qty,
       uom, action, action_note)
    VALUES
      (p_bill_id,
       COALESCE(NULLIF(v_item ->> 'item_name', ''), 'Item'),
       COALESCE((v_item ->> 'ordered_qty')::numeric, 0),
       COALESCE((v_item ->> 'billed_qty')::numeric, 0),
       COALESCE((v_item ->> 'received_qty')::numeric, 0),
       COALESCE(NULLIF(v_item ->> 'uom', ''), 'units'),
       NULLIF(v_item ->> 'action', ''),
       NULLIF(v_item ->> 'action_note', ''));
  END LOOP;

  FOR v_doc IN SELECT * FROM jsonb_array_elements(COALESCE(p_documents, '[]'::jsonb)) LOOP
    INSERT INTO public.gin_bill_documents
      (gin_bill_id, name, type, storage_path, uploaded_by)
    VALUES
      (p_bill_id,
       COALESCE(NULLIF(v_doc ->> 'name', ''), 'document'),
       COALESCE(NULLIF(v_doc ->> 'type', ''), 'photo'),
       NULLIF(v_doc ->> 'storage_path', ''),
       v_email);
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'id', p_bill_id, 'status', 'pending');
END $function$;

CREATE OR REPLACE FUNCTION public.gin_hod_review(p_bill_id uuid, p_decision text, p_note text DEFAULT NULL::text, p_item_actions jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_bill public.gin_bills%ROWTYPE;
  v_act jsonb;
  v_email text := auth.jwt() ->> 'email';
BEGIN
  -- TENANT GUARD: only the owning department may operate on this record.
  IF NOT public.is_same_tenant(
        (SELECT g.hod_id FROM public.gin_bills g WHERE g.id = p_bill_id)
  ) THEN
    RAISE EXCEPTION 'Forbidden: data does not belong to your department';
  END IF;
  IF p_decision NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid decision';
  END IF;

  SELECT * INTO v_bill FROM public.gin_bills WHERE id = p_bill_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GIN bill not found';
  END IF;
  IF v_bill.hod_status = 'approved' THEN
    RAISE EXCEPTION 'GIN is already approved';
  END IF;

  -- Optional per-line HOD actions (shown back on the supervisor table).
  FOR v_act IN SELECT * FROM jsonb_array_elements(COALESCE(p_item_actions, '[]'::jsonb)) LOOP
    UPDATE public.gin_bill_items
      SET hod_action = NULLIF(v_act ->> 'hod_action', ''),
          hod_action_note = NULLIF(v_act ->> 'hod_action_note', '')
      WHERE id = (v_act ->> 'item_id')::uuid
        AND gin_bill_id = p_bill_id;
  END LOOP;

  IF p_decision = 'approved' THEN
    UPDATE public.gin_bills
      SET hod_status = 'approved',
          hod_note = p_note,
          hod_reviewed_by = v_email,
          hod_reviewed_at = now(),
          status = 'approved',
          updated_at = now()
      WHERE id = p_bill_id;
    RETURN public.gin_add_to_stock(p_bill_id);
  ELSE
    UPDATE public.gin_bills
      SET hod_status = 'rejected',
          hod_note = p_note,
          hod_reviewed_by = v_email,
          hod_reviewed_at = now(),
          status = 'rejected',
          updated_at = now()
      WHERE id = p_bill_id;
    RETURN jsonb_build_object('ok', true, 'status', 'rejected');
  END IF;
END $function$;

CREATE OR REPLACE FUNCTION public.gin_add_to_stock(p_bill_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  -- TENANT GUARD: only the owning department may operate on this record.
  IF NOT public.is_same_tenant(
        (SELECT g.hod_id FROM public.gin_bills g WHERE g.id = p_bill_id)
  ) THEN
    RAISE EXCEPTION 'Forbidden: data does not belong to your department';
  END IF;
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

  -- If this GIN was created from a stock order (bill_number = order_no),
  -- move the whole order group to 'added_to_stock' too. No-op otherwise.
  UPDATE public.stock_orders
    SET status = 'added_to_stock', updated_at = now()
    WHERE order_no = v_bill.bill_number
      AND status = 'received';

  RETURN jsonb_build_object('ok', true, 'added', v_added,
                            'skipped', to_jsonb(v_skipped), 'status', 'added_to_stock');
END $function$;

CREATE OR REPLACE FUNCTION public.gin_create_from_order(p_order_no text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_order RECORD;
  v_bill_id uuid;
  v_gin_no text;
  v_email text := auth.jwt() ->> 'email';
  v_thavvu_point_id text;
  v_thavvu_point_name text;
  v_count int := 0;
BEGIN
  -- TENANT GUARD: only the owning department may operate on this record.
  IF NOT public.is_same_tenant(
        (SELECT o.hod_id FROM public.stock_orders o WHERE o.order_no = p_order_no LIMIT 1)
  ) THEN
    RAISE EXCEPTION 'Forbidden: data does not belong to your department';
  END IF;
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
END $function$;

CREATE OR REPLACE FUNCTION public.stock_manual_entry(p_item_name text, p_quantity numeric, p_thavvu_point_id text, p_thavvu_point_name text, p_uom text DEFAULT 'units'::text, p_batch text DEFAULT NULL::text, p_note text DEFAULT NULL::text, p_item_code text DEFAULT NULL::text, p_site_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_item_id text;
  v_item_code text;
  v_batch text;
  v_balance_id text;
  v_email text := auth.jwt() ->> 'email';
BEGIN
  -- TENANT GUARD: only the owning department may operate on this record.
  IF NOT public.is_same_tenant(
        (SELECT tp.hod_id FROM public.thavvu_points tp WHERE tp.id = p_thavvu_point_id)
  ) THEN
    RAISE EXCEPTION 'Forbidden: data does not belong to your department';
  END IF;
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
END $function$;

CREATE OR REPLACE FUNCTION public.stock_place_multi_order(p_order_no text, p_site_id text, p_stock_point_id text, p_stock_point_name text, p_items jsonb, p_thavvu_point_id text DEFAULT NULL::text, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_item jsonb;
  v_email text := auth.jwt() ->> 'email';
  v_batch text;
  v_item_id text;
  v_item_code text;
  v_count int := 0;
BEGIN
  -- TENANT GUARD: only the owning department may operate on this record.
  IF NOT public.is_same_tenant(
        (SELECT tp.hod_id FROM public.thavvu_points tp WHERE tp.id = p_stock_point_id)
  ) THEN
    RAISE EXCEPTION 'Forbidden: data does not belong to your department';
  END IF;
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
        WHERE id = trim(v_item ->> 'item_id')
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
       v_item_id::uuid,
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
END $function$;

CREATE OR REPLACE FUNCTION public.issue_stock_for_module(p_site_id text, p_module text, p_source_reference text, p_stock_balance_id text, p_quantity numeric, p_note text DEFAULT NULL::text)
 RETURNS TABLE(usage_event_id uuid, remaining_quantity numeric, was_already_issued boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_balance public.stock_batch_balances%ROWTYPE;
  v_event_id uuid;
  v_uom text;
BEGIN
  -- TENANT GUARD: only the owning department may operate on this record.
  IF NOT public.is_same_tenant(
        (SELECT s.hod_id FROM public.sites s WHERE s.id = p_site_id)
  ) THEN
    RAISE EXCEPTION 'Forbidden: data does not belong to your department';
  END IF;
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication is required'; END IF;
  IF coalesce(trim(p_module), '') = '' OR coalesce(trim(p_source_reference), '') = '' THEN
    RAISE EXCEPTION 'Module and source reference are required';
  END IF;
  IF p_quantity IS NULL OR p_quantity <= 0 THEN RAISE EXCEPTION 'Quantity must be greater than zero'; END IF;

  SELECT * INTO v_balance FROM public.stock_batch_balances
  WHERE id = p_stock_balance_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Stock balance not found'; END IF;

  SELECT id INTO v_event_id FROM public.stock_usage_events
  WHERE module = p_module AND source_reference = p_source_reference
    AND stock_balance_id = p_stock_balance_id;
  IF FOUND THEN
    RETURN QUERY SELECT v_event_id, v_balance.available_qty, true;
    RETURN;
  END IF;
  IF v_balance.available_qty < p_quantity THEN
    RAISE EXCEPTION 'Insufficient stock. Available: %, requested: %', v_balance.available_qty, p_quantity;
  END IF;

  SELECT coalesce(nullif(primary_uom, ''), nullif(uom, ''), 'units') INTO v_uom
  FROM public.stock_items WHERE id = v_balance.item_id;
  v_uom := coalesce(v_uom, 'units');

  UPDATE public.stock_batch_balances
  SET available_qty = available_qty - p_quantity, updated_at = now()
  WHERE id = v_balance.id RETURNING * INTO v_balance;

  INSERT INTO public.stock_usage_events
    (site_id, module, source_reference, stock_balance_id, stock_point_id, item_id, batch_id, quantity, uom, note, issued_by)
  VALUES
    (p_site_id, p_module, p_source_reference, v_balance.id, v_balance.stock_point_id, v_balance.item_id,
     v_balance.batch_id, p_quantity, v_uom, p_note, auth.uid())
  RETURNING id INTO v_event_id;

  INSERT INTO public.stock_consumption
    (site_id, stock_point_id, stock_point_name, item_id, item_name, batch_id, batch_code, quantity, loose_quantity, uom, reason, consumed_by)
  VALUES
    (p_site_id, v_balance.stock_point_id, v_balance.stock_point_name, v_balance.item_id, v_balance.item_name,
     v_balance.batch_id, v_balance.batch_code, p_quantity, 0, v_uom,
     concat(p_module, ': ', coalesce(p_note, p_source_reference)), coalesce(auth.jwt() ->> 'email', auth.uid()::text));

  INSERT INTO public.stock_movements
    (reference_id, movement_type, item_id, batch_balance_id, batch_id, from_stock_point_id, quantity, loose_quantity, reason, created_at)
  VALUES
    (p_source_reference, 'issue', v_balance.item_id, v_balance.id, v_balance.batch_id,
     v_balance.stock_point_id, p_quantity, 0, concat(p_module, ': ', coalesce(p_note, 'Stock issued')), now());

  RETURN QUERY SELECT v_event_id, v_balance.available_qty, false;
END;
$function$;

