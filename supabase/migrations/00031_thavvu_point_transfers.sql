-- ============================================================================
-- Migration 00031: Enterprise Thavvu-Point stock transfers.
--
-- The enterprise model has NO separate warehouse/stock-point layer: stock
-- lives AT the Thavvu Point (created by HOD), and internal transfers move
-- goods FROM one Thavvu Point TO another so every transfer is tracked per
-- point ("which point were the goods sent to").
--
-- 1. stock_transfers gains explicit from/to Thavvu Point columns (additive;
--    the legacy from_point_id/to_point_id columns now carry the Thavvu Point
--    id too so deliver/receive balance operations keep working).
-- 2. Demo stock balances are re-pointed from the old stock points (SP-001..3)
--    to the demo Thavvu Points (TP-VJA-001 / TP-VJA-002). Idempotent: the
--    UPDATEs only match the legacy SP ids, so re-runs are no-ops.
-- 3. Existing demo transfer rows are backfilled with their Thavvu Points.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Thavvu Point columns on stock_transfers
-- ---------------------------------------------------------------------------
ALTER TABLE public.stock_transfers ADD COLUMN IF NOT EXISTS from_thavvu_point_id text;
ALTER TABLE public.stock_transfers ADD COLUMN IF NOT EXISTS from_thavvu_point text;
ALTER TABLE public.stock_transfers ADD COLUMN IF NOT EXISTS to_thavvu_point_id text;
ALTER TABLE public.stock_transfers ADD COLUMN IF NOT EXISTS to_thavvu_point text;

CREATE INDEX IF NOT EXISTS idx_stock_transfers_from_point ON public.stock_transfers(from_thavvu_point_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_to_point ON public.stock_transfers(to_thavvu_point_id);

-- ---------------------------------------------------------------------------
-- 2. Re-point demo stock balances to Thavvu Points (no warehouse layer)
-- ---------------------------------------------------------------------------
UPDATE public.stock_batch_balances
SET stock_point_id = 'TP-VJA-001',
    stock_point_name = 'East Ramp Loading Point',
    location = 'East Ramp Loading Point'
WHERE stock_point_id = 'SP-001';

UPDATE public.stock_batch_balances
SET stock_point_id = 'TP-VJA-002',
    stock_point_name = 'River Sand Screening Point',
    location = 'River Sand Screening Point'
WHERE stock_point_id = 'SP-002';

UPDATE public.stock_batch_balances
SET stock_point_id = 'TP-VJA-001',
    stock_point_name = 'East Ramp Loading Point',
    location = 'East Ramp Loading Point'
WHERE stock_point_id = 'SP-003';

-- ---------------------------------------------------------------------------
-- 3. Backfill existing demo transfers with their Thavvu Points
-- ---------------------------------------------------------------------------
UPDATE public.stock_transfers
SET from_thavvu_point_id = 'TP-VJA-001',
    from_thavvu_point = 'East Ramp Loading Point'
WHERE from_point_id = 'SP-001' AND from_thavvu_point_id IS NULL;

UPDATE public.stock_transfers
SET from_thavvu_point_id = 'TP-VJA-002',
    from_thavvu_point = 'River Sand Screening Point'
WHERE from_point_id = 'SP-002' AND from_thavvu_point_id IS NULL;

UPDATE public.stock_transfers
SET from_thavvu_point_id = 'TP-VJA-001',
    from_thavvu_point = 'East Ramp Loading Point'
WHERE from_point_id = 'SP-003' AND from_thavvu_point_id IS NULL;

UPDATE public.stock_transfers
SET to_thavvu_point_id = 'TP-VJA-001',
    to_thavvu_point = 'East Ramp Loading Point'
WHERE to_point_id = 'SP-001' AND to_thavvu_point_id IS NULL;

UPDATE public.stock_transfers
SET to_thavvu_point_id = 'TP-VJA-002',
    to_thavvu_point = 'River Sand Screening Point'
WHERE to_point_id = 'SP-002' AND to_thavvu_point_id IS NULL;

UPDATE public.stock_transfers
SET to_thavvu_point_id = 'TP-VJA-001',
    to_thavvu_point = 'East Ramp Loading Point'
WHERE to_point_id = 'SP-003' AND to_thavvu_point_id IS NULL;
