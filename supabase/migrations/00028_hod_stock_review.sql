-- ============================================================================
-- Migration 00028: HOD Stock visibility + GIN action review.
--
-- Adds the missing production columns for the HOD stock module:
--   1. stock_items.reorder_level   → low-stock detection per item
--   2. stock_gin_bills hod review  → HOD approves / rejects / comments on
--      supervisor GIN actions so the receive→review→stock flow closes.
--
-- All columns are additive and idempotent (ADD COLUMN IF NOT EXISTS).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. stock_items.reorder_level — item-level low-stock threshold
-- ---------------------------------------------------------------------------
ALTER TABLE public.stock_items ADD COLUMN IF NOT EXISTS reorder_level numeric(14, 2) NOT NULL DEFAULT 0;

-- Backfill sensible reorder levels for the seeded demo catalog so the HOD
-- Stock tab can show low-stock badges immediately.
UPDATE public.stock_items SET reorder_level = 50    WHERE item_code = 'CEM-OPC53' AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 500   WHERE item_code = 'STL-TMT8'  AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 500   WHERE item_code = 'STL-TMT12' AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 20    WHERE item_code = 'SND-RVR'   AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 20    WHERE item_code = 'MET-20MM'  AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 200   WHERE item_code = 'DSL-HSD'   AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 40    WHERE item_code = 'OIL-ENG'   AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 2000  WHERE item_code = 'BRK-CLAY'  AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 50    WHERE item_code = 'WIR-BND'   AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 40    WHERE item_code = 'PLY-SHT'   AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 5     WHERE item_code = 'PNT-WHT'   AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 50    WHERE item_code = 'PVC-1IN'   AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 10    WHERE item_code = 'WIR-2.5'   AND reorder_level = 0;
UPDATE public.stock_items SET reorder_level = 50    WHERE item_code = 'NIL-45MM'  AND reorder_level = 0;

-- ---------------------------------------------------------------------------
-- 2. stock_gin_bills — HOD review of supervisor GIN actions
-- ---------------------------------------------------------------------------
ALTER TABLE public.stock_gin_bills ADD COLUMN IF NOT EXISTS hod_status text NOT NULL DEFAULT 'pending'
  CHECK (hod_status IN ('pending', 'approved', 'rejected'));
ALTER TABLE public.stock_gin_bills ADD COLUMN IF NOT EXISTS hod_note text;
ALTER TABLE public.stock_gin_bills ADD COLUMN IF NOT EXISTS hod_reviewed_by text;
ALTER TABLE public.stock_gin_bills ADD COLUMN IF NOT EXISTS hod_reviewed_at timestamptz;

-- ---------------------------------------------------------------------------
-- 3. Indexes for the HOD review queue
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_gin_hod_status ON public.stock_gin_bills(hod_status, created_at);
CREATE INDEX IF NOT EXISTS idx_stock_items_reorder ON public.stock_items(reorder_level);
