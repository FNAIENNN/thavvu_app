-- ============================================================================
-- Migration 00036: GIN bill update / resubmit.
--
-- The supervisor can correct a bill that is still pending OR was rejected
-- by HOD (the reject → fix → resubmit loop). Updates the header, replaces
-- line items and documents, resets hod review state and re-opens the bill
-- as pending so it appears again on the HOD approval queue.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.gin_update_bill(
  p_bill_id uuid,
  p_bill_number text,
  p_supplier_name text,
  p_thavvu_point_id text,
  p_thavvu_point_name text,
  p_items jsonb,
  p_supplier_id text DEFAULT NULL,
  p_site_id text DEFAULT NULL,
  p_bill_date date DEFAULT NULL,
  p_documents jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_bill public.gin_bills%ROWTYPE;
  v_item jsonb;
  v_doc jsonb;
  v_email text := auth.jwt() ->> 'email';
BEGIN
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
END $$;
