-- Correct the usage-event/consumption UOM from the stock item catalog.
CREATE OR REPLACE FUNCTION public.issue_stock_for_module(
  p_site_id text,
  p_module text,
  p_source_reference text,
  p_stock_balance_id text,
  p_quantity numeric,
  p_note text DEFAULT NULL
)
RETURNS TABLE (
  usage_event_id uuid,
  remaining_quantity numeric,
  was_already_issued boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance public.stock_batch_balances%ROWTYPE;
  v_event_id uuid;
  v_uom text;
BEGIN
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
$$;
