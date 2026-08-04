-- ============================================================================
-- Migration 00022: Atomic, idempotent stock usage for supervisor modules.
--
-- All live modules must use public.issue_stock_for_module rather than updating
-- stock_batch_balances from the client. The function locks the balance row,
-- rejects insufficient inventory, creates one movement/audit record, and is
-- idempotent by (module, source_reference, balance).
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.stock_usage_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text REFERENCES public.sites(id) ON DELETE SET NULL,
  module text NOT NULL,
  source_reference text NOT NULL,
  stock_balance_id text NOT NULL REFERENCES public.stock_batch_balances(id),
  stock_point_id text,
  item_id uuid,
  batch_id text,
  quantity numeric(14, 2) NOT NULL CHECK (quantity > 0),
  uom text NOT NULL DEFAULT 'units',
  note text,
  issued_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (module, source_reference, stock_balance_id)
);

ALTER TABLE public.stock_usage_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stock_usage_events_read_authenticated" ON public.stock_usage_events;
CREATE POLICY "stock_usage_events_read_authenticated"
  ON public.stock_usage_events FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Direct inserts/updates/deletes are intentionally denied. Usage must be
-- issued through the SECURITY DEFINER function below.
REVOKE INSERT, UPDATE, DELETE ON public.stock_usage_events FROM anon, authenticated;

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
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication is required';
  END IF;
  IF coalesce(trim(p_module), '') = '' OR coalesce(trim(p_source_reference), '') = '' THEN
    RAISE EXCEPTION 'Module and source reference are required';
  END IF;
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be greater than zero';
  END IF;

  SELECT * INTO v_balance
  FROM public.stock_batch_balances
  WHERE id = p_stock_balance_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stock balance not found';
  END IF;

  SELECT id INTO v_event_id
  FROM public.stock_usage_events
  WHERE module = p_module
    AND source_reference = p_source_reference
    AND stock_balance_id = p_stock_balance_id;

  IF FOUND THEN
    RETURN QUERY SELECT v_event_id, v_balance.available_qty, true;
    RETURN;
  END IF;

  IF v_balance.available_qty < p_quantity THEN
    RAISE EXCEPTION 'Insufficient stock. Available: %, requested: %',
      v_balance.available_qty, p_quantity;
  END IF;

  UPDATE public.stock_batch_balances
  SET available_qty = available_qty - p_quantity,
      updated_at = now()
  WHERE id = v_balance.id
  RETURNING * INTO v_balance;

  INSERT INTO public.stock_usage_events (
    site_id, module, source_reference, stock_balance_id, stock_point_id,
    item_id, batch_id, quantity, uom, note, issued_by
  ) VALUES (
    p_site_id, p_module, p_source_reference, v_balance.id,
    v_balance.stock_point_id, v_balance.item_id, v_balance.batch_id,
    p_quantity, coalesce(nullif(v_balance.item_code, ''), 'units'), p_note,
    auth.uid()
  ) RETURNING id INTO v_event_id;

  INSERT INTO public.stock_consumption (
    site_id, stock_point_id, stock_point_name, item_id, item_name,
    batch_id, batch_code, quantity, loose_quantity, uom, reason,
    consumed_by
  ) VALUES (
    p_site_id, v_balance.stock_point_id, v_balance.stock_point_name,
    v_balance.item_id, v_balance.item_name, v_balance.batch_id,
    v_balance.batch_code, p_quantity, 0,
    coalesce(nullif(v_balance.item_code, ''), 'units'),
    concat(p_module, ': ', coalesce(p_note, p_source_reference)),
    coalesce(auth.jwt() ->> 'email', auth.uid()::text)
  );

  INSERT INTO public.stock_movements (
    reference_id, movement_type, item_id, batch_balance_id, batch_id,
    from_stock_point_id, quantity, loose_quantity, reason, created_at
  ) VALUES (
    p_source_reference, 'issue', v_balance.item_id, v_balance.id,
    v_balance.batch_id, v_balance.stock_point_id, p_quantity, 0,
    concat(p_module, ': ', coalesce(p_note, 'Stock issued')), now()
  );

  RETURN QUERY SELECT v_event_id, v_balance.available_qty, false;
END;
$$;

REVOKE ALL ON FUNCTION public.issue_stock_for_module(text, text, text, text, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.issue_stock_for_module(text, text, text, text, numeric, text) TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'stock_usage_events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.stock_usage_events;
  END IF;
END $$;
