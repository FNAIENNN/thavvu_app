-- ============================================================================
-- Migration 00037: TEMPORARY diagnostic for gin_add_to_stock (text = uuid).
-- Creates an approved bill and runs gin_add_to_stock inside an exception
-- handler that reports the exact failing statement. Dropped by 00038.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.gin_diag()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v jsonb;
  v_msg text;
  v_detail text;
  v_context text;
  v_bill uuid;
BEGIN
  INSERT INTO public.gin_bills
    (gin_no, bill_number, supplier_name, thavvu_point_id, thavvu_point_name,
     status, hod_status)
  VALUES
    ('GIN-DIAG-1', 'DIAG-1', 'Diag Supplier', 'TP-VJA-001', 'Diag Point',
     'approved', 'approved')
  RETURNING id INTO v_bill;

  INSERT INTO public.gin_bill_items
    (gin_bill_id, item_name, ordered_qty, billed_qty, received_qty)
  VALUES
    (v_bill, 'Cement OPC 53 Grade', 1, 1, 1);

  BEGIN
    SELECT public.gin_add_to_stock(v_bill) INTO v;
    RETURN jsonb_build_object('ok', true, 'result', v);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS
      v_msg = MESSAGE_TEXT,
      v_detail = PG_EXCEPTION_DETAIL,
      v_context = PG_EXCEPTION_CONTEXT;
    RETURN jsonb_build_object('ok', false, 'msg', v_msg,
                              'detail', v_detail, 'context', v_context);
  END;
END $$;
