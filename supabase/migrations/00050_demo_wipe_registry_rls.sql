-- ============================================================================
-- Migration 00050: Demo data wiped everywhere + machine_assets RLS.
--
-- 1. Deletes every demo/transactional row in every module so the app starts
--    REAL-WORLD EMPTY: no workers, suppliers, machines, attendance, food,
--    payments, cash, rental, tasks, maps, transfers, stock, GIN, orders.
--    KEPT (structural/reference): auth users, profiles, sites,
--    thavvu_points, site_memberships, thavvu_point_assignments,
--    stock_items master catalog, rental_catalogs reference, telegram config.
--    Users now build everything themselves through the new Add/Delete UI.
--
-- 2. machine_assets gets proper RLS (select/insert/update for members) so
--    supervisors + HOD can add machines and soft-delete (is_active=false).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Wipe demo/transactional rows (dependency order)
-- ---------------------------------------------------------------------------

-- Attendance / food / payments
DELETE FROM public.attendance_batch_workers;
DELETE FROM public.attendance_batches;
DELETE FROM public.attendance_records;
DELETE FROM public.food_requests;
DELETE FROM public.food_submissions;
DELETE FROM public.supplier_bills;
DELETE FROM public.supplier_payment_requests;
DELETE FROM public.payment_ledger;
DELETE FROM public.payment_accounts;

-- Machines (logs before assets; assignments before assets/workers)
DELETE FROM public.machine_daily_diesel_lines;
DELETE FROM public.machine_daily_logs;
DELETE FROM public.machine_attachments;
DELETE FROM public.machine_audit_logs;
DELETE FROM public.machine_finance_requests;
DELETE FROM public.machine_payment_requests;
DELETE FROM public.machine_assignments;
DELETE FROM public.machine_suppliers;
DELETE FROM public.machine_assets;

-- Stock / GIN / transfers
DELETE FROM public.gin_bill_documents;
DELETE FROM public.gin_bill_items;
DELETE FROM public.gin_bills;
DELETE FROM public.stock_usage_events;
DELETE FROM public.stock_transfers;
DELETE FROM public.stock_consumption;
DELETE FROM public.stock_orders;
DELETE FROM public.stock_movements;
DELETE FROM public.stock_batch_balances;
DELETE FROM public.stock_gin_bills;

-- Cash / rental / tasks / maps
DELETE FROM public.cash_allocations;
DELETE FROM public.cash_transactions;
DELETE FROM public.rental_entries;
DELETE FROM public.rental_fuel_lines;
DELETE FROM public.rental_payments;
DELETE FROM public.rental_returns;
DELETE FROM public.rental_transfers;
DELETE FROM public.task_steps;
DELETE FROM public.tasks;
DELETE FROM public.hod_map_uploads;
DELETE FROM public.module_alerts;
DELETE FROM public.hod_login_approvals;

-- Registries (all rows were demo seeds)
DELETE FROM public.workers;
DELETE FROM public.suppliers;

-- ---------------------------------------------------------------------------
-- 2. machine_assets RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.machine_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "machine_assets_select_members" ON public.machine_assets;
CREATE POLICY "machine_assets_select_members" ON public.machine_assets FOR SELECT
  USING (public.is_site_member(site_id) OR public.is_demo_login());

DROP POLICY IF EXISTS "machine_assets_insert_members" ON public.machine_assets;
CREATE POLICY "machine_assets_insert_members" ON public.machine_assets FOR INSERT
  WITH CHECK (public.is_site_member(site_id) OR public.is_demo_login());

DROP POLICY IF EXISTS "machine_assets_update_members" ON public.machine_assets;
CREATE POLICY "machine_assets_update_members" ON public.machine_assets FOR UPDATE
  USING (public.is_site_member(site_id) OR public.is_demo_login())
  WITH CHECK (public.is_site_member(site_id) OR public.is_demo_login());
