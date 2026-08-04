-- ============================================================================
-- Migration 00030: Stock transfer receive checklist.
--
-- Separates the deliver side from the receive side of an internal transfer:
--   * The DELIVERER marks a transfer delivered (stock leaves the sender).
--   * The RECEIVER verifies a checklist, records the actually received
--     quantity + condition + notes, and only then is stock added to the
--     receiver point.
--
-- All additions are additive + idempotent so this migration can be re-run.
-- ============================================================================

ALTER TABLE public.stock_transfers ADD COLUMN IF NOT EXISTS received_quantity numeric(14, 2);
ALTER TABLE public.stock_transfers ADD COLUMN IF NOT EXISTS received_condition text;
ALTER TABLE public.stock_transfers ADD COLUMN IF NOT EXISTS receive_checklist jsonb;
ALTER TABLE public.stock_transfers ADD COLUMN IF NOT EXISTS receive_notes text;
ALTER TABLE public.stock_transfers ADD COLUMN IF NOT EXISTS received_by_name text;

-- Realtime already publishes stock_transfers (added in 00021); the new
-- columns ride along automatically.
