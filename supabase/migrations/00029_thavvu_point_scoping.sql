-- ============================================================================
-- Migration 00029: Thavvu Point scoping for ALL module tables.
--
-- The main key point of the enterprise model: the HOD creates a Thavvu
-- Point, assigns it to a supervisor, and EVERY data row the supervisor
-- enters in any module stores the thavvu_point_id. Reports then aggregate
-- per point.
--
-- Machine / workers / attendance / food already carry thavvu_point_id
-- (00002 / 00005). This migration adds it to the remaining module tables:
-- rental, cash, tasks, maps, stock. All additions are additive + idempotent.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. RENTAL
-- ---------------------------------------------------------------------------
ALTER TABLE public.rental_entries ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;
ALTER TABLE public.rental_fuel_lines ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;
ALTER TABLE public.rental_transfers ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;
ALTER TABLE public.rental_returns ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;
ALTER TABLE public.rental_payments ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_rental_entries_point ON public.rental_entries(thavvu_point_id);
CREATE INDEX IF NOT EXISTS idx_rental_fuel_lines_point ON public.rental_fuel_lines(thavvu_point_id);
CREATE INDEX IF NOT EXISTS idx_rental_transfers_point ON public.rental_transfers(thavvu_point_id);
CREATE INDEX IF NOT EXISTS idx_rental_returns_point ON public.rental_returns(thavvu_point_id);
CREATE INDEX IF NOT EXISTS idx_rental_payments_point ON public.rental_payments(thavvu_point_id);

-- ---------------------------------------------------------------------------
-- 2. CASH
-- ---------------------------------------------------------------------------
ALTER TABLE public.cash_allocations ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;
ALTER TABLE public.cash_transactions ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_cash_allocations_point ON public.cash_allocations(thavvu_point_id);
CREATE INDEX IF NOT EXISTS idx_cash_transactions_point ON public.cash_transactions(thavvu_point_id);

-- ---------------------------------------------------------------------------
-- 3. TASKS
-- ---------------------------------------------------------------------------
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;
ALTER TABLE public.task_steps ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_point ON public.tasks(thavvu_point_id);
CREATE INDEX IF NOT EXISTS idx_task_steps_point ON public.task_steps(thavvu_point_id);

-- ---------------------------------------------------------------------------
-- 4. MAPS
-- ---------------------------------------------------------------------------
ALTER TABLE public.hod_map_uploads ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_map_uploads_point ON public.hod_map_uploads(thavvu_point_id);

-- ---------------------------------------------------------------------------
-- 5. STOCK
-- ---------------------------------------------------------------------------
ALTER TABLE public.stock_orders ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;
ALTER TABLE public.stock_gin_bills ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;
ALTER TABLE public.stock_consumption ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;
ALTER TABLE public.stock_transfers ADD COLUMN IF NOT EXISTS thavvu_point_id text
  REFERENCES public.thavvu_points(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_stock_orders_point ON public.stock_orders(thavvu_point_id);
CREATE INDEX IF NOT EXISTS idx_stock_gin_bills_point ON public.stock_gin_bills(thavvu_point_id);
CREATE INDEX IF NOT EXISTS idx_stock_consumption_point ON public.stock_consumption(thavvu_point_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_point ON public.stock_transfers(thavvu_point_id);

-- ---------------------------------------------------------------------------
-- 6. DEMO BACKFILL — map SITE-VJA-001 rows to TP-VJA-001 so the demo
--    supervisor's data is already point-scoped. Only touches demo seeds.
-- ---------------------------------------------------------------------------
UPDATE public.rental_entries
SET thavvu_point_id = 'TP-VJA-001'
WHERE site_id = 'SITE-VJA-001' AND thavvu_point_id IS NULL;

UPDATE public.rental_fuel_lines
SET thavvu_point_id = 'TP-VJA-001'
WHERE thavvu_point_id IS NULL
  AND entry_id IN (
    SELECT id FROM public.rental_entries WHERE site_id = 'SITE-VJA-001'
  );

UPDATE public.cash_allocations
SET thavvu_point_id = 'TP-VJA-001'
WHERE site_id = 'SITE-VJA-001' AND thavvu_point_id IS NULL;

UPDATE public.cash_transactions
SET thavvu_point_id = 'TP-VJA-001'
WHERE site_id = 'SITE-VJA-001' AND thavvu_point_id IS NULL;

UPDATE public.tasks
SET thavvu_point_id = 'TP-VJA-001'
WHERE site_id = 'SITE-VJA-001' AND thavvu_point_id IS NULL;

UPDATE public.hod_map_uploads
SET thavvu_point_id = 'TP-VJA-001'
WHERE site_id = 'SITE-VJA-001' AND thavvu_point_id IS NULL;

UPDATE public.stock_orders
SET thavvu_point_id = 'TP-VJA-001'
WHERE site_id = 'SITE-VJA-001' AND thavvu_point_id IS NULL;

UPDATE public.stock_gin_bills
SET thavvu_point_id = 'TP-VJA-001'
WHERE site_id = 'SITE-VJA-001' AND thavvu_point_id IS NULL;

UPDATE public.stock_consumption
SET thavvu_point_id = 'TP-VJA-001'
WHERE site_id = 'SITE-VJA-001' AND thavvu_point_id IS NULL;

UPDATE public.stock_transfers
SET thavvu_point_id = 'TP-VJA-001'
WHERE site_id = 'SITE-VJA-001' AND thavvu_point_id IS NULL;

-- ---------------------------------------------------------------------------
-- 7. RLS helper — thavvu_point_scoped access for site members.
--    A user can read/write a point's rows if they can read the site.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_point_member(p_point_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.thavvu_points tp
    WHERE tp.id = p_point_id
      AND (
        public.is_site_member(tp.site_id)
        OR public.is_demo_login()
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- 8. RLS policies — every point-scoped table gets a site-member fallback
--    that also allows the row when the caller is a member of the point's site.
--    Existing site-scoped policies stay untouched; these are additive.
-- ---------------------------------------------------------------------------
-- rental_entries already has site RLS from 00026; add point-based select/insert.
DROP POLICY IF EXISTS "rental_entries_select_point" ON public.rental_entries;
CREATE POLICY "rental_entries_select_point" ON public.rental_entries FOR SELECT
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));
DROP POLICY IF EXISTS "rental_entries_insert_point" ON public.rental_entries;
CREATE POLICY "rental_entries_insert_point" ON public.rental_entries FOR INSERT
  WITH CHECK (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));
DROP POLICY IF EXISTS "rental_entries_update_point" ON public.rental_entries;
CREATE POLICY "rental_entries_update_point" ON public.rental_entries FOR UPDATE
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));

-- cash_transactions
DROP POLICY IF EXISTS "cash_transactions_select_point" ON public.cash_transactions;
CREATE POLICY "cash_transactions_select_point" ON public.cash_transactions FOR SELECT
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));
DROP POLICY IF EXISTS "cash_transactions_insert_point" ON public.cash_transactions;
CREATE POLICY "cash_transactions_insert_point" ON public.cash_transactions FOR INSERT
  WITH CHECK (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));
DROP POLICY IF EXISTS "cash_transactions_update_point" ON public.cash_transactions;
CREATE POLICY "cash_transactions_update_point" ON public.cash_transactions FOR UPDATE
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));

-- tasks
DROP POLICY IF EXISTS "tasks_select_point" ON public.tasks;
CREATE POLICY "tasks_select_point" ON public.tasks FOR SELECT
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));
DROP POLICY IF EXISTS "tasks_insert_point" ON public.tasks;
CREATE POLICY "tasks_insert_point" ON public.tasks FOR INSERT
  WITH CHECK (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));
DROP POLICY IF EXISTS "tasks_update_point" ON public.tasks;
CREATE POLICY "tasks_update_point" ON public.tasks FOR UPDATE
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));

-- hod_map_uploads
DROP POLICY IF EXISTS "map_uploads_select_point" ON public.hod_map_uploads;
CREATE POLICY "map_uploads_select_point" ON public.hod_map_uploads FOR SELECT
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));
DROP POLICY IF EXISTS "map_uploads_insert_point" ON public.hod_map_uploads;
CREATE POLICY "map_uploads_insert_point" ON public.hod_map_uploads FOR INSERT
  WITH CHECK (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));

-- stock_transfers (HOD Transfers + Internal Transfer review)
DROP POLICY IF EXISTS "stock_transfers_select_point" ON public.stock_transfers;
CREATE POLICY "stock_transfers_select_point" ON public.stock_transfers FOR SELECT
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));
DROP POLICY IF EXISTS "stock_transfers_insert_point" ON public.stock_transfers;
CREATE POLICY "stock_transfers_insert_point" ON public.stock_transfers FOR INSERT
  WITH CHECK (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));

-- stock_consumption
DROP POLICY IF EXISTS "stock_consumption_select_point" ON public.stock_consumption;
CREATE POLICY "stock_consumption_select_point" ON public.stock_consumption FOR SELECT
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));

-- stock_gin_bills
DROP POLICY IF EXISTS "stock_gin_select_point" ON public.stock_gin_bills;
CREATE POLICY "stock_gin_select_point" ON public.stock_gin_bills FOR SELECT
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));
DROP POLICY IF EXISTS "stock_gin_update_point" ON public.stock_gin_bills;
CREATE POLICY "stock_gin_update_point" ON public.stock_gin_bills FOR UPDATE
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));

-- stock_orders
DROP POLICY IF EXISTS "stock_orders_select_point" ON public.stock_orders;
CREATE POLICY "stock_orders_select_point" ON public.stock_orders FOR SELECT
  USING (thavvu_point_id IS NULL OR public.is_point_member(thavvu_point_id));
