-- ============================================================================
-- 00062_thavvu_tenant_data_isolation.sql
-- Multi-tenant data isolation: every record carries hod_id (owning HOD).
--   * ADD hod_id to every data table (skips tables that already have it)
--   * Backfill from site/point/creator/parent chain (legacy single-tenant data)
--   * BEFORE INSERT trigger stamps hod_id from the authenticated user
--   * RLS rewritten from site-membership to tenant (is_same_tenant) checks
-- ============================================================================

-- Shared stamping trigger ------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_stamp_hod_id()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.hod_id IS NULL THEN
    NEW.hod_id := public.current_hod_id();
  END IF;
  RETURN NEW;
END;
$function$;

-- attendance_batches -------------------------------------------------------------
ALTER TABLE public.attendance_batches ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.attendance_batches SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = attendance_batches.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.attendance_batches ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_attendance_batches_hod_id BEFORE INSERT ON public.attendance_batches
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.attendance_batches'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.attendance_batches', rec.polname);
  END LOOP;
END $$;
CREATE POLICY attendance_batches_tenant_select ON public.attendance_batches FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY attendance_batches_tenant_insert ON public.attendance_batches FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY attendance_batches_tenant_update ON public.attendance_batches FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY attendance_batches_tenant_delete ON public.attendance_batches FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- attendance_records -------------------------------------------------------------
ALTER TABLE public.attendance_records ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.attendance_records SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = attendance_records.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.attendance_records ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_attendance_records_hod_id BEFORE INSERT ON public.attendance_records
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.attendance_records'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.attendance_records', rec.polname);
  END LOOP;
END $$;
CREATE POLICY attendance_records_tenant_select ON public.attendance_records FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY attendance_records_tenant_insert ON public.attendance_records FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY attendance_records_tenant_update ON public.attendance_records FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY attendance_records_tenant_delete ON public.attendance_records FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- cash_allocations -------------------------------------------------------------
ALTER TABLE public.cash_allocations ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.cash_allocations SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = cash_allocations.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.cash_allocations ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_cash_allocations_hod_id BEFORE INSERT ON public.cash_allocations
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.cash_allocations'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.cash_allocations', rec.polname);
  END LOOP;
END $$;
CREATE POLICY cash_allocations_tenant_select ON public.cash_allocations FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY cash_allocations_tenant_insert ON public.cash_allocations FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY cash_allocations_tenant_update ON public.cash_allocations FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY cash_allocations_tenant_delete ON public.cash_allocations FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- food_requests -------------------------------------------------------------
ALTER TABLE public.food_requests ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.food_requests SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = food_requests.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.food_requests ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_food_requests_hod_id BEFORE INSERT ON public.food_requests
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.food_requests'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.food_requests', rec.polname);
  END LOOP;
END $$;
CREATE POLICY food_requests_tenant_select ON public.food_requests FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY food_requests_tenant_insert ON public.food_requests FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY food_requests_tenant_update ON public.food_requests FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY food_requests_tenant_delete ON public.food_requests FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- food_submissions -------------------------------------------------------------
ALTER TABLE public.food_submissions ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.food_submissions SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = food_submissions.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.food_submissions ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_food_submissions_hod_id BEFORE INSERT ON public.food_submissions
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.food_submissions'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.food_submissions', rec.polname);
  END LOOP;
END $$;
CREATE POLICY food_submissions_tenant_select ON public.food_submissions FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY food_submissions_tenant_insert ON public.food_submissions FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY food_submissions_tenant_update ON public.food_submissions FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY food_submissions_tenant_delete ON public.food_submissions FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- gin_bills -------------------------------------------------------------
ALTER TABLE public.gin_bills ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.gin_bills SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = gin_bills.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.gin_bills ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_gin_bills_hod_id BEFORE INSERT ON public.gin_bills
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.gin_bills'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.gin_bills', rec.polname);
  END LOOP;
END $$;
CREATE POLICY gin_bills_tenant_select ON public.gin_bills FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY gin_bills_tenant_insert ON public.gin_bills FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY gin_bills_tenant_update ON public.gin_bills FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY gin_bills_tenant_delete ON public.gin_bills FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- hod_map_uploads -------------------------------------------------------------
ALTER TABLE public.hod_map_uploads ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.hod_map_uploads SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = hod_map_uploads.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.hod_map_uploads ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_hod_map_uploads_hod_id BEFORE INSERT ON public.hod_map_uploads
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.hod_map_uploads'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.hod_map_uploads', rec.polname);
  END LOOP;
END $$;
CREATE POLICY hod_map_uploads_tenant_select ON public.hod_map_uploads FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY hod_map_uploads_tenant_insert ON public.hod_map_uploads FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY hod_map_uploads_tenant_update ON public.hod_map_uploads FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY hod_map_uploads_tenant_delete ON public.hod_map_uploads FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- machine_assignments -------------------------------------------------------------
ALTER TABLE public.machine_assignments ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.machine_assignments SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = machine_assignments.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.machine_assignments ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_machine_assignments_hod_id BEFORE INSERT ON public.machine_assignments
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.machine_assignments'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.machine_assignments', rec.polname);
  END LOOP;
END $$;
CREATE POLICY machine_assignments_tenant_select ON public.machine_assignments FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY machine_assignments_tenant_insert ON public.machine_assignments FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_assignments_tenant_update ON public.machine_assignments FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_assignments_tenant_delete ON public.machine_assignments FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- machine_audit_logs -------------------------------------------------------------
ALTER TABLE public.machine_audit_logs ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.machine_audit_logs SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = machine_audit_logs.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.machine_audit_logs ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_machine_audit_logs_hod_id BEFORE INSERT ON public.machine_audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.machine_audit_logs'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.machine_audit_logs', rec.polname);
  END LOOP;
END $$;
CREATE POLICY machine_audit_logs_tenant_select ON public.machine_audit_logs FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY machine_audit_logs_tenant_insert ON public.machine_audit_logs FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_audit_logs_tenant_update ON public.machine_audit_logs FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_audit_logs_tenant_delete ON public.machine_audit_logs FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- machine_payment_requests -------------------------------------------------------------
ALTER TABLE public.machine_payment_requests ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.machine_payment_requests SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = machine_payment_requests.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.machine_payment_requests ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_machine_payment_requests_hod_id BEFORE INSERT ON public.machine_payment_requests
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.machine_payment_requests'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.machine_payment_requests', rec.polname);
  END LOOP;
END $$;
CREATE POLICY machine_payment_requests_tenant_select ON public.machine_payment_requests FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY machine_payment_requests_tenant_insert ON public.machine_payment_requests FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_payment_requests_tenant_update ON public.machine_payment_requests FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_payment_requests_tenant_delete ON public.machine_payment_requests FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- module_alerts -------------------------------------------------------------
ALTER TABLE public.module_alerts ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.module_alerts SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = module_alerts.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.module_alerts ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_module_alerts_hod_id BEFORE INSERT ON public.module_alerts
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.module_alerts'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.module_alerts', rec.polname);
  END LOOP;
END $$;
CREATE POLICY module_alerts_tenant_select ON public.module_alerts FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY module_alerts_tenant_insert ON public.module_alerts FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY module_alerts_tenant_update ON public.module_alerts FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY module_alerts_tenant_delete ON public.module_alerts FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- payment_accounts -------------------------------------------------------------
ALTER TABLE public.payment_accounts ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.payment_accounts SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = payment_accounts.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.payment_accounts ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_payment_accounts_hod_id BEFORE INSERT ON public.payment_accounts
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.payment_accounts'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.payment_accounts', rec.polname);
  END LOOP;
END $$;
CREATE POLICY payment_accounts_tenant_select ON public.payment_accounts FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY payment_accounts_tenant_insert ON public.payment_accounts FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY payment_accounts_tenant_update ON public.payment_accounts FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY payment_accounts_tenant_delete ON public.payment_accounts FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- payment_ledger -------------------------------------------------------------
ALTER TABLE public.payment_ledger ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.payment_ledger SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = payment_ledger.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.payment_ledger ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_payment_ledger_hod_id BEFORE INSERT ON public.payment_ledger
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.payment_ledger'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.payment_ledger', rec.polname);
  END LOOP;
END $$;
CREATE POLICY payment_ledger_tenant_select ON public.payment_ledger FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY payment_ledger_tenant_insert ON public.payment_ledger FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY payment_ledger_tenant_update ON public.payment_ledger FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY payment_ledger_tenant_delete ON public.payment_ledger FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- stock_consumption -------------------------------------------------------------
ALTER TABLE public.stock_consumption ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.stock_consumption SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = stock_consumption.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.stock_consumption ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_stock_consumption_hod_id BEFORE INSERT ON public.stock_consumption
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.stock_consumption'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.stock_consumption', rec.polname);
  END LOOP;
END $$;
CREATE POLICY stock_consumption_tenant_select ON public.stock_consumption FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY stock_consumption_tenant_insert ON public.stock_consumption FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_consumption_tenant_update ON public.stock_consumption FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_consumption_tenant_delete ON public.stock_consumption FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- stock_gin_bills -------------------------------------------------------------
ALTER TABLE public.stock_gin_bills ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.stock_gin_bills SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = stock_gin_bills.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.stock_gin_bills ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_stock_gin_bills_hod_id BEFORE INSERT ON public.stock_gin_bills
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.stock_gin_bills'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.stock_gin_bills', rec.polname);
  END LOOP;
END $$;
CREATE POLICY stock_gin_bills_tenant_select ON public.stock_gin_bills FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY stock_gin_bills_tenant_insert ON public.stock_gin_bills FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_gin_bills_tenant_update ON public.stock_gin_bills FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_gin_bills_tenant_delete ON public.stock_gin_bills FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- stock_orders -------------------------------------------------------------
ALTER TABLE public.stock_orders ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.stock_orders SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = stock_orders.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.stock_orders ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_stock_orders_hod_id BEFORE INSERT ON public.stock_orders
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.stock_orders'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.stock_orders', rec.polname);
  END LOOP;
END $$;
CREATE POLICY stock_orders_tenant_select ON public.stock_orders FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY stock_orders_tenant_insert ON public.stock_orders FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_orders_tenant_update ON public.stock_orders FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_orders_tenant_delete ON public.stock_orders FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- stock_transfers -------------------------------------------------------------
ALTER TABLE public.stock_transfers ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.stock_transfers SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = stock_transfers.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.stock_transfers ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_stock_transfers_hod_id BEFORE INSERT ON public.stock_transfers
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.stock_transfers'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.stock_transfers', rec.polname);
  END LOOP;
END $$;
CREATE POLICY stock_transfers_tenant_select ON public.stock_transfers FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY stock_transfers_tenant_insert ON public.stock_transfers FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_transfers_tenant_update ON public.stock_transfers FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_transfers_tenant_delete ON public.stock_transfers FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- stock_usage_events -------------------------------------------------------------
ALTER TABLE public.stock_usage_events ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.stock_usage_events SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = stock_usage_events.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.stock_usage_events ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_stock_usage_events_hod_id BEFORE INSERT ON public.stock_usage_events
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.stock_usage_events'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.stock_usage_events', rec.polname);
  END LOOP;
END $$;
CREATE POLICY stock_usage_events_tenant_select ON public.stock_usage_events FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY stock_usage_events_tenant_insert ON public.stock_usage_events FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_usage_events_tenant_update ON public.stock_usage_events FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_usage_events_tenant_delete ON public.stock_usage_events FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- supplier_payment_requests -------------------------------------------------------------
ALTER TABLE public.supplier_payment_requests ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.supplier_payment_requests SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = supplier_payment_requests.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.supplier_payment_requests ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_supplier_payment_requests_hod_id BEFORE INSERT ON public.supplier_payment_requests
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.supplier_payment_requests'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.supplier_payment_requests', rec.polname);
  END LOOP;
END $$;
CREATE POLICY supplier_payment_requests_tenant_select ON public.supplier_payment_requests FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY supplier_payment_requests_tenant_insert ON public.supplier_payment_requests FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY supplier_payment_requests_tenant_update ON public.supplier_payment_requests FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY supplier_payment_requests_tenant_delete ON public.supplier_payment_requests FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- tasks -------------------------------------------------------------
ALTER TABLE public.tasks ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.tasks SET hod_id = (SELECT s.hod_id FROM public.sites s WHERE s.id = tasks.site_id) WHERE hod_id IS NULL;
ALTER TABLE public.tasks ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_tasks_hod_id BEFORE INSERT ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.tasks'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.tasks', rec.polname);
  END LOOP;
END $$;
CREATE POLICY tasks_tenant_select ON public.tasks FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY tasks_tenant_insert ON public.tasks FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY tasks_tenant_update ON public.tasks FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY tasks_tenant_delete ON public.tasks FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- machine_assets -------------------------------------------------------------
ALTER TABLE public.machine_assets ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.machine_assets SET hod_id = COALESCE((SELECT s.hod_id FROM public.sites s WHERE s.id = machine_assets.site_id), (SELECT p.hod_id FROM public.profiles p WHERE p.id = machine_assets.created_by)) WHERE hod_id IS NULL;
ALTER TABLE public.machine_assets ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_machine_assets_hod_id BEFORE INSERT ON public.machine_assets
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.machine_assets'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.machine_assets', rec.polname);
  END LOOP;
END $$;
CREATE POLICY machine_assets_tenant_select ON public.machine_assets FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY machine_assets_tenant_insert ON public.machine_assets FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_assets_tenant_update ON public.machine_assets FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_assets_tenant_delete ON public.machine_assets FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- machine_suppliers -------------------------------------------------------------
ALTER TABLE public.machine_suppliers ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.machine_suppliers SET hod_id = COALESCE((SELECT s.hod_id FROM public.sites s WHERE s.id = machine_suppliers.site_id), (SELECT p.hod_id FROM public.profiles p WHERE p.id = machine_suppliers.created_by)) WHERE hod_id IS NULL;
ALTER TABLE public.machine_suppliers ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_machine_suppliers_hod_id BEFORE INSERT ON public.machine_suppliers
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.machine_suppliers'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.machine_suppliers', rec.polname);
  END LOOP;
END $$;
CREATE POLICY machine_suppliers_tenant_select ON public.machine_suppliers FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY machine_suppliers_tenant_insert ON public.machine_suppliers FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_suppliers_tenant_update ON public.machine_suppliers FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_suppliers_tenant_delete ON public.machine_suppliers FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- rental_catalogs -------------------------------------------------------------
ALTER TABLE public.rental_catalogs ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.rental_catalogs SET hod_id = COALESCE((SELECT s.hod_id FROM public.sites s WHERE s.id = rental_catalogs.site_id), (SELECT p.hod_id FROM public.profiles p WHERE p.id = rental_catalogs.created_by)) WHERE hod_id IS NULL;
ALTER TABLE public.rental_catalogs ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_rental_catalogs_hod_id BEFORE INSERT ON public.rental_catalogs
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.rental_catalogs'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.rental_catalogs', rec.polname);
  END LOOP;
END $$;
CREATE POLICY rental_catalogs_tenant_select ON public.rental_catalogs FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY rental_catalogs_tenant_insert ON public.rental_catalogs FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_catalogs_tenant_update ON public.rental_catalogs FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_catalogs_tenant_delete ON public.rental_catalogs FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- supplier_bills -------------------------------------------------------------
ALTER TABLE public.supplier_bills ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.supplier_bills SET hod_id = COALESCE((SELECT s.hod_id FROM public.sites s WHERE s.id = supplier_bills.site_id), (SELECT p.hod_id FROM public.profiles p WHERE p.id = supplier_bills.created_by)) WHERE hod_id IS NULL;
ALTER TABLE public.supplier_bills ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_supplier_bills_hod_id BEFORE INSERT ON public.supplier_bills
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.supplier_bills'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.supplier_bills', rec.polname);
  END LOOP;
END $$;
CREATE POLICY supplier_bills_tenant_select ON public.supplier_bills FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY supplier_bills_tenant_insert ON public.supplier_bills FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY supplier_bills_tenant_update ON public.supplier_bills FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY supplier_bills_tenant_delete ON public.supplier_bills FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- suppliers -------------------------------------------------------------
ALTER TABLE public.suppliers ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.suppliers SET hod_id = COALESCE((SELECT s.hod_id FROM public.sites s WHERE s.id = suppliers.site_id), (SELECT tp.hod_id FROM public.thavvu_points tp WHERE tp.id = suppliers.thavvu_point_id)) WHERE hod_id IS NULL;
ALTER TABLE public.suppliers ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_suppliers_hod_id BEFORE INSERT ON public.suppliers
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.suppliers'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.suppliers', rec.polname);
  END LOOP;
END $$;
CREATE POLICY suppliers_tenant_select ON public.suppliers FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY suppliers_tenant_insert ON public.suppliers FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY suppliers_tenant_update ON public.suppliers FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY suppliers_tenant_delete ON public.suppliers FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- workers -------------------------------------------------------------
ALTER TABLE public.workers ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.workers SET hod_id = COALESCE((SELECT s.hod_id FROM public.sites s WHERE s.id = workers.site_id), (SELECT tp.hod_id FROM public.thavvu_points tp WHERE tp.id = workers.thavvu_point_id), (SELECT p.hod_id FROM public.profiles p WHERE p.id = workers.created_by)) WHERE hod_id IS NULL;
ALTER TABLE public.workers ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_workers_hod_id BEFORE INSERT ON public.workers
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.workers'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.workers', rec.polname);
  END LOOP;
END $$;
CREATE POLICY workers_tenant_select ON public.workers FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY workers_tenant_insert ON public.workers FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY workers_tenant_update ON public.workers FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY workers_tenant_delete ON public.workers FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- cash_transactions -------------------------------------------------------------
UPDATE public.cash_transactions SET hod_id = COALESCE(cash_transactions.hod_id, (SELECT s.hod_id FROM public.sites s WHERE s.id = cash_transactions.site_id)) WHERE hod_id IS NULL;
ALTER TABLE public.cash_transactions ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_cash_transactions_hod_id BEFORE INSERT ON public.cash_transactions
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.cash_transactions'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.cash_transactions', rec.polname);
  END LOOP;
END $$;
CREATE POLICY cash_transactions_tenant_select ON public.cash_transactions FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY cash_transactions_tenant_insert ON public.cash_transactions FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY cash_transactions_tenant_update ON public.cash_transactions FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY cash_transactions_tenant_delete ON public.cash_transactions FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- machine_daily_logs -------------------------------------------------------------
UPDATE public.machine_daily_logs SET hod_id = COALESCE(machine_daily_logs.hod_id, (SELECT s.hod_id FROM public.sites s WHERE s.id = machine_daily_logs.site_id)) WHERE hod_id IS NULL;
ALTER TABLE public.machine_daily_logs ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_machine_daily_logs_hod_id BEFORE INSERT ON public.machine_daily_logs
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.machine_daily_logs'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.machine_daily_logs', rec.polname);
  END LOOP;
END $$;
CREATE POLICY machine_daily_logs_tenant_select ON public.machine_daily_logs FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY machine_daily_logs_tenant_insert ON public.machine_daily_logs FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_daily_logs_tenant_update ON public.machine_daily_logs FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_daily_logs_tenant_delete ON public.machine_daily_logs FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- machine_finance_requests -------------------------------------------------------------
UPDATE public.machine_finance_requests SET hod_id = COALESCE(machine_finance_requests.hod_id, (SELECT s.hod_id FROM public.sites s WHERE s.id = machine_finance_requests.site_id)) WHERE hod_id IS NULL;
ALTER TABLE public.machine_finance_requests ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_machine_finance_requests_hod_id BEFORE INSERT ON public.machine_finance_requests
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.machine_finance_requests'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.machine_finance_requests', rec.polname);
  END LOOP;
END $$;
CREATE POLICY machine_finance_requests_tenant_select ON public.machine_finance_requests FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY machine_finance_requests_tenant_insert ON public.machine_finance_requests FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_finance_requests_tenant_update ON public.machine_finance_requests FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_finance_requests_tenant_delete ON public.machine_finance_requests FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- rental_entries -------------------------------------------------------------
UPDATE public.rental_entries SET hod_id = COALESCE(rental_entries.hod_id, (SELECT s.hod_id FROM public.sites s WHERE s.id = rental_entries.site_id)) WHERE hod_id IS NULL;
ALTER TABLE public.rental_entries ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_rental_entries_hod_id BEFORE INSERT ON public.rental_entries
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.rental_entries'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.rental_entries', rec.polname);
  END LOOP;
END $$;
CREATE POLICY rental_entries_tenant_select ON public.rental_entries FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY rental_entries_tenant_insert ON public.rental_entries FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_entries_tenant_update ON public.rental_entries FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_entries_tenant_delete ON public.rental_entries FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- rental_payments -------------------------------------------------------------
UPDATE public.rental_payments SET hod_id = COALESCE(rental_payments.hod_id, (SELECT s.hod_id FROM public.sites s WHERE s.id = rental_payments.site_id)) WHERE hod_id IS NULL;
ALTER TABLE public.rental_payments ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_rental_payments_hod_id BEFORE INSERT ON public.rental_payments
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.rental_payments'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.rental_payments', rec.polname);
  END LOOP;
END $$;
CREATE POLICY rental_payments_tenant_select ON public.rental_payments FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY rental_payments_tenant_insert ON public.rental_payments FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_payments_tenant_update ON public.rental_payments FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_payments_tenant_delete ON public.rental_payments FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- rental_returns -------------------------------------------------------------
UPDATE public.rental_returns SET hod_id = COALESCE(rental_returns.hod_id, (SELECT s.hod_id FROM public.sites s WHERE s.id = rental_returns.site_id)) WHERE hod_id IS NULL;
ALTER TABLE public.rental_returns ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_rental_returns_hod_id BEFORE INSERT ON public.rental_returns
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.rental_returns'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.rental_returns', rec.polname);
  END LOOP;
END $$;
CREATE POLICY rental_returns_tenant_select ON public.rental_returns FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY rental_returns_tenant_insert ON public.rental_returns FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_returns_tenant_update ON public.rental_returns FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_returns_tenant_delete ON public.rental_returns FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- rental_transfers -------------------------------------------------------------
UPDATE public.rental_transfers SET hod_id = COALESCE(rental_transfers.hod_id, (SELECT s.hod_id FROM public.sites s WHERE s.id = rental_transfers.site_id)) WHERE hod_id IS NULL;
ALTER TABLE public.rental_transfers ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_rental_transfers_hod_id BEFORE INSERT ON public.rental_transfers
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.rental_transfers'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.rental_transfers', rec.polname);
  END LOOP;
END $$;
CREATE POLICY rental_transfers_tenant_select ON public.rental_transfers FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY rental_transfers_tenant_insert ON public.rental_transfers FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_transfers_tenant_update ON public.rental_transfers FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_transfers_tenant_delete ON public.rental_transfers FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- rental_fuel_lines -------------------------------------------------------------
ALTER TABLE public.rental_fuel_lines ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.rental_fuel_lines SET hod_id = COALESCE((SELECT r.hod_id FROM public.rental_entries r WHERE r.id = rental_fuel_lines.entry_id), (SELECT tp.hod_id FROM public.thavvu_points tp WHERE tp.id = rental_fuel_lines.thavvu_point_id)) WHERE hod_id IS NULL;
ALTER TABLE public.rental_fuel_lines ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_rental_fuel_lines_hod_id BEFORE INSERT ON public.rental_fuel_lines
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.rental_fuel_lines'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.rental_fuel_lines', rec.polname);
  END LOOP;
END $$;
CREATE POLICY rental_fuel_lines_tenant_select ON public.rental_fuel_lines FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY rental_fuel_lines_tenant_insert ON public.rental_fuel_lines FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_fuel_lines_tenant_update ON public.rental_fuel_lines FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY rental_fuel_lines_tenant_delete ON public.rental_fuel_lines FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- task_steps -------------------------------------------------------------
ALTER TABLE public.task_steps ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.task_steps SET hod_id = COALESCE((SELECT tk.hod_id FROM public.tasks tk WHERE tk.id = task_steps.task_id), (SELECT tp.hod_id FROM public.thavvu_points tp WHERE tp.id = task_steps.thavvu_point_id)) WHERE hod_id IS NULL;
ALTER TABLE public.task_steps ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_task_steps_hod_id BEFORE INSERT ON public.task_steps
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.task_steps'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.task_steps', rec.polname);
  END LOOP;
END $$;
CREATE POLICY task_steps_tenant_select ON public.task_steps FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY task_steps_tenant_insert ON public.task_steps FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY task_steps_tenant_update ON public.task_steps FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY task_steps_tenant_delete ON public.task_steps FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- attendance_batch_workers -------------------------------------------------------------
ALTER TABLE public.attendance_batch_workers ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.attendance_batch_workers SET hod_id = (SELECT b.hod_id FROM public.attendance_batches b WHERE b.id = attendance_batch_workers.batch_id) WHERE hod_id IS NULL;
ALTER TABLE public.attendance_batch_workers ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_attendance_batch_workers_hod_id BEFORE INSERT ON public.attendance_batch_workers
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.attendance_batch_workers'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.attendance_batch_workers', rec.polname);
  END LOOP;
END $$;
CREATE POLICY attendance_batch_workers_tenant_select ON public.attendance_batch_workers FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY attendance_batch_workers_tenant_insert ON public.attendance_batch_workers FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY attendance_batch_workers_tenant_update ON public.attendance_batch_workers FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY attendance_batch_workers_tenant_delete ON public.attendance_batch_workers FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- gin_bill_documents -------------------------------------------------------------
ALTER TABLE public.gin_bill_documents ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.gin_bill_documents SET hod_id = (SELECT g.hod_id FROM public.gin_bills g WHERE g.id = gin_bill_documents.gin_bill_id) WHERE hod_id IS NULL;
ALTER TABLE public.gin_bill_documents ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_gin_bill_documents_hod_id BEFORE INSERT ON public.gin_bill_documents
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.gin_bill_documents'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.gin_bill_documents', rec.polname);
  END LOOP;
END $$;
CREATE POLICY gin_bill_documents_tenant_select ON public.gin_bill_documents FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY gin_bill_documents_tenant_insert ON public.gin_bill_documents FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY gin_bill_documents_tenant_update ON public.gin_bill_documents FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY gin_bill_documents_tenant_delete ON public.gin_bill_documents FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- gin_bill_items -------------------------------------------------------------
ALTER TABLE public.gin_bill_items ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.gin_bill_items SET hod_id = (SELECT g.hod_id FROM public.gin_bills g WHERE g.id = gin_bill_items.gin_bill_id) WHERE hod_id IS NULL;
ALTER TABLE public.gin_bill_items ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_gin_bill_items_hod_id BEFORE INSERT ON public.gin_bill_items
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.gin_bill_items'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.gin_bill_items', rec.polname);
  END LOOP;
END $$;
CREATE POLICY gin_bill_items_tenant_select ON public.gin_bill_items FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY gin_bill_items_tenant_insert ON public.gin_bill_items FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY gin_bill_items_tenant_update ON public.gin_bill_items FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY gin_bill_items_tenant_delete ON public.gin_bill_items FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- machine_attachments -------------------------------------------------------------
ALTER TABLE public.machine_attachments ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
CREATE TRIGGER trg_machine_attachments_hod_id BEFORE INSERT ON public.machine_attachments
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.machine_attachments'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.machine_attachments', rec.polname);
  END LOOP;
END $$;
CREATE POLICY machine_attachments_tenant_select ON public.machine_attachments FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY machine_attachments_tenant_insert ON public.machine_attachments FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_attachments_tenant_update ON public.machine_attachments FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_attachments_tenant_delete ON public.machine_attachments FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- machine_daily_diesel_lines -------------------------------------------------------------
ALTER TABLE public.machine_daily_diesel_lines ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.machine_daily_diesel_lines SET hod_id = (SELECT m.hod_id FROM public.machine_daily_logs m WHERE m.id = machine_daily_diesel_lines.daily_log_id) WHERE hod_id IS NULL;
ALTER TABLE public.machine_daily_diesel_lines ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_machine_daily_diesel_lines_hod_id BEFORE INSERT ON public.machine_daily_diesel_lines
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.machine_daily_diesel_lines'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.machine_daily_diesel_lines', rec.polname);
  END LOOP;
END $$;
CREATE POLICY machine_daily_diesel_lines_tenant_select ON public.machine_daily_diesel_lines FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY machine_daily_diesel_lines_tenant_insert ON public.machine_daily_diesel_lines FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_daily_diesel_lines_tenant_update ON public.machine_daily_diesel_lines FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY machine_daily_diesel_lines_tenant_delete ON public.machine_daily_diesel_lines FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- stock_batch_balances -------------------------------------------------------------
ALTER TABLE public.stock_batch_balances ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.stock_batch_balances SET hod_id = (SELECT tp.hod_id FROM public.thavvu_points tp WHERE tp.id = stock_batch_balances.stock_point_id) WHERE hod_id IS NULL;
ALTER TABLE public.stock_batch_balances ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_stock_batch_balances_hod_id BEFORE INSERT ON public.stock_batch_balances
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.stock_batch_balances'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.stock_batch_balances', rec.polname);
  END LOOP;
END $$;
CREATE POLICY stock_batch_balances_tenant_select ON public.stock_batch_balances FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY stock_batch_balances_tenant_insert ON public.stock_batch_balances FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_batch_balances_tenant_update ON public.stock_batch_balances FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_batch_balances_tenant_delete ON public.stock_batch_balances FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- stock_movements -------------------------------------------------------------
ALTER TABLE public.stock_movements ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.stock_movements SET hod_id = (SELECT tp.hod_id FROM public.thavvu_points tp WHERE tp.id = stock_movements.from_stock_point_id) WHERE hod_id IS NULL;
ALTER TABLE public.stock_movements ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_stock_movements_hod_id BEFORE INSERT ON public.stock_movements
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.stock_movements'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.stock_movements', rec.polname);
  END LOOP;
END $$;
CREATE POLICY stock_movements_tenant_select ON public.stock_movements FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY stock_movements_tenant_insert ON public.stock_movements FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_movements_tenant_update ON public.stock_movements FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_movements_tenant_delete ON public.stock_movements FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- stock_items -------------------------------------------------------------
ALTER TABLE public.stock_items ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.stock_items SET hod_id = (SELECT id FROM public.profiles WHERE role = 'hod' ORDER BY created_at LIMIT 1) WHERE hod_id IS NULL;
ALTER TABLE public.stock_items ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_stock_items_hod_id BEFORE INSERT ON public.stock_items
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.stock_items'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.stock_items', rec.polname);
  END LOOP;
END $$;
CREATE POLICY stock_items_tenant_select ON public.stock_items FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY stock_items_tenant_insert ON public.stock_items FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_items_tenant_update ON public.stock_items FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY stock_items_tenant_delete ON public.stock_items FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- thavvu_point_assignments -------------------------------------------------------------
ALTER TABLE public.thavvu_point_assignments ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
UPDATE public.thavvu_point_assignments SET hod_id = COALESCE((SELECT p.hod_id FROM public.profiles p WHERE p.id = thavvu_point_assignments.supervisor_id), (SELECT s.hod_id FROM public.sites s WHERE s.id = thavvu_point_assignments.site_id)) WHERE hod_id IS NULL;
ALTER TABLE public.thavvu_point_assignments ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_thavvu_point_assignments_hod_id BEFORE INSERT ON public.thavvu_point_assignments
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.thavvu_point_assignments'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.thavvu_point_assignments', rec.polname);
  END LOOP;
END $$;
CREATE POLICY thavvu_point_assignments_tenant_select ON public.thavvu_point_assignments FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY thavvu_point_assignments_tenant_insert ON public.thavvu_point_assignments FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY thavvu_point_assignments_tenant_update ON public.thavvu_point_assignments FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY thavvu_point_assignments_tenant_delete ON public.thavvu_point_assignments FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- sites (owner) ---------------------------------------------------------
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.sites'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.sites', rec.polname);
  END LOOP;
END $$;
CREATE POLICY sites_tenant_select ON public.sites FOR SELECT
  USING (public.is_same_tenant(hod_id) OR public.is_site_member(id));
CREATE POLICY sites_tenant_insert ON public.sites FOR INSERT
  WITH CHECK (public.is_same_tenant(COALESCE(hod_id, public.current_hod_id())));
CREATE TRIGGER trg_sites_hod_id BEFORE INSERT ON public.sites
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
CREATE POLICY sites_tenant_update ON public.sites FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY sites_tenant_delete ON public.sites FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- thavvu_points (owner, supervisor access via membership) ------------------
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.thavvu_points'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.thavvu_points', rec.polname);
  END LOOP;
END $$;
CREATE POLICY points_tenant_select ON public.thavvu_points FOR SELECT
  USING (public.is_same_tenant(hod_id) OR public.is_point_member(id));
CREATE POLICY points_tenant_insert ON public.thavvu_points FOR INSERT
  WITH CHECK (
    public.is_same_tenant(COALESCE(hod_id, public.current_hod_id()))
    AND COALESCE(hod_id, public.current_hod_id()) =
        (SELECT s.hod_id FROM public.sites s WHERE s.id = site_id)
  );
CREATE TRIGGER trg_thavvu_points_hod_id BEFORE INSERT ON public.thavvu_points
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();
CREATE POLICY points_tenant_update ON public.thavvu_points FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY points_tenant_delete ON public.thavvu_points FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- site_memberships (own membership or tenant site) ------------------------
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.site_memberships'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.site_memberships', rec.polname);
  END LOOP;
END $$;
CREATE POLICY memberships_select_tenant ON public.site_memberships FOR SELECT
  USING (
    profile_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.sites s WHERE s.id = site_id AND public.is_same_tenant(s.hod_id))
  );
CREATE POLICY memberships_insert_tenant ON public.site_memberships FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.sites s WHERE s.id = site_id AND public.is_same_tenant(s.hod_id))
  );
CREATE POLICY memberships_update_tenant ON public.site_memberships FOR UPDATE
  USING (
    profile_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.sites s WHERE s.id = site_id AND public.is_same_tenant(s.hod_id))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.sites s WHERE s.id = site_id AND public.is_same_tenant(s.hod_id))
  );
CREATE POLICY memberships_delete_tenant ON public.site_memberships FOR DELETE
  USING (
    profile_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.sites s WHERE s.id = site_id AND public.is_same_tenant(s.hod_id))
  );

-- supervisor_registration_requests (HOD intake; hod_id stamped at approval) -
ALTER TABLE public.supervisor_registration_requests ADD COLUMN hod_id UUID REFERENCES public.profiles(id);
DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy WHERE polrelid = 'public.supervisor_registration_requests'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.supervisor_registration_requests', rec.polname);
  END LOOP;
END $$;
CREATE POLICY requests_select_hod ON public.supervisor_registration_requests FOR SELECT
  USING (public.has_role(ARRAY['hod', 'admin']) OR public.is_demo_login());
CREATE POLICY requests_update_hod ON public.supervisor_registration_requests FOR UPDATE
  USING (public.has_role(ARRAY['hod', 'admin']) OR public.is_demo_login())
  WITH CHECK (public.has_role(ARRAY['hod', 'admin']) OR public.is_demo_login());

