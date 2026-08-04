-- Thavvu App: Machine Workflow Tables
-- Suppliers, assets, daily logs, payments, finance, audit, alerts

-- ============================================================
-- 6. MACHINE SUPPLIERS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.machine_suppliers (
  id            TEXT PRIMARY KEY,  -- e.g. SUPPLIER-001
  site_id       TEXT NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  type          TEXT NOT NULL DEFAULT 'permanent' CHECK (type IN ('permanent', 'temporary', 'all')),
  phone         TEXT,
  rating        NUMERIC(3,1) DEFAULT 0,
  valid_until   DATE,
  notes         TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_by    UUID NOT NULL REFERENCES public.profiles(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_machine_suppliers_site ON public.machine_suppliers(site_id);
CREATE UNIQUE INDEX idx_machine_suppliers_site_name ON public.machine_suppliers(site_id, name);

CREATE TRIGGER trg_machine_suppliers_updated_at
  BEFORE UPDATE ON public.machine_suppliers
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 7. MACHINE ASSETS (catalog)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.machine_assets (
  id              TEXT PRIMARY KEY,  -- e.g. MACHINE-001
  site_id         TEXT NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  machine_name    TEXT NOT NULL,
  vehicle_number  TEXT NOT NULL,
  vehicle_type    TEXT NOT NULL,
  operator_name   TEXT NOT NULL,
  operator_phone  TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_by      UUID NOT NULL REFERENCES public.profiles(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_machine_assets_site ON public.machine_assets(site_id);
CREATE UNIQUE INDEX idx_machine_assets_vehicle ON public.machine_assets(site_id, vehicle_number);

CREATE TRIGGER trg_machine_assets_updated_at
  BEFORE UPDATE ON public.machine_assets
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 8. MACHINE ASSIGNMENTS (which machine works for which thavvu point)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.machine_assignments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_id        TEXT NOT NULL REFERENCES public.machine_assets(id) ON DELETE CASCADE,
  thavvu_point_id   TEXT NOT NULL REFERENCES public.thavvu_points(id) ON DELETE CASCADE,
  site_id           TEXT NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  assigned_by       UUID NOT NULL REFERENCES public.profiles(id),
  is_active         BOOLEAN NOT NULL DEFAULT true,
  assigned_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at          TIMESTAMPTZ
);

-- Partial unique index: only one ACTIVE assignment per machine/point pair.
CREATE UNIQUE INDEX idx_machine_assignments_active_unique
  ON public.machine_assignments(machine_id, thavvu_point_id)
  WHERE is_active = true;

CREATE INDEX idx_machine_assignments_point ON public.machine_assignments(thavvu_point_id);
CREATE INDEX idx_machine_assignments_machine ON public.machine_assignments(machine_id);

-- ============================================================
-- 9. MACHINE DAILY LOGS
-- ============================================================
CREATE TYPE machine_log_status AS ENUM (
  'draft', 'submitted', 'approved', 'revision_requested', 'rejected'
);

CREATE TABLE IF NOT EXISTS public.machine_daily_logs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  log_date          DATE NOT NULL DEFAULT CURRENT_DATE,
  site_id           TEXT NOT NULL REFERENCES public.sites(id),
  thavvu_point_id   TEXT NOT NULL REFERENCES public.thavvu_points(id),
  supervisor_id     UUID NOT NULL REFERENCES public.profiles(id),
  machine_id        TEXT NOT NULL REFERENCES public.machine_assets(id),
  machine_assignment_id UUID REFERENCES public.machine_assignments(id),
  location          TEXT,
  diesel_option     TEXT CHECK (diesel_option IN ('With diesel', 'Without diesel', 'Fuel issued from stock point')),
  working_hours     NUMERIC(6,2) DEFAULT 0,
  worker_count      INTEGER DEFAULT 0,
  beta_amount       NUMERIC(12,2) DEFAULT 0,
  extra_beta_amount NUMERIC(12,2) DEFAULT 0,
  notes             TEXT,
  bill_file_path    TEXT,
  status            machine_log_status NOT NULL DEFAULT 'draft',
  hod_id            UUID REFERENCES public.profiles(id),
  hod_note          TEXT,
  reviewed_at       TIMESTAMPTZ,
  submitted_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_machine_daily_logs_date ON public.machine_daily_logs(log_date DESC);
CREATE INDEX idx_machine_daily_logs_site ON public.machine_daily_logs(site_id);
CREATE INDEX idx_machine_daily_logs_point ON public.machine_daily_logs(thavvu_point_id);
CREATE INDEX idx_machine_daily_logs_supervisor ON public.machine_daily_logs(supervisor_id);
CREATE INDEX idx_machine_daily_logs_status ON public.machine_daily_logs(status);
CREATE UNIQUE INDEX idx_machine_daily_logs_unique_day
  ON public.machine_daily_logs(machine_id, log_date)
  WHERE status NOT IN ('rejected', 'draft');

CREATE TRIGGER trg_machine_daily_logs_updated_at
  BEFORE UPDATE ON public.machine_daily_logs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 10. MACHINE DAILY DIESEL LINES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.machine_daily_diesel_lines (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  daily_log_id      UUID NOT NULL REFERENCES public.machine_daily_logs(id) ON DELETE CASCADE,
  fuel_type         TEXT NOT NULL DEFAULT 'Diesel',
  stock_point       TEXT,
  liters            NUMERIC(10,2) NOT NULL DEFAULT 0,
  amount            NUMERIC(12,2) NOT NULL DEFAULT 0,
  remarks           TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_diesel_lines_log ON public.machine_daily_diesel_lines(daily_log_id);

-- ============================================================
-- 11. MACHINE PAYMENT REQUESTS
-- ============================================================
CREATE TYPE machine_payment_kind AS ENUM ('cash', 'advance');

CREATE TYPE machine_payment_status AS ENUM (
  'draft', 'hod_approved', 'hod_rejected',
  'submitted_to_finance', 'finance_processing', 'paid', 'closed'
);

CREATE TABLE IF NOT EXISTS public.machine_payment_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  daily_log_id      UUID REFERENCES public.machine_daily_logs(id) ON DELETE SET NULL,
  machine_entry_id  TEXT,
  site_id           TEXT NOT NULL REFERENCES public.sites(id),
  thavvu_point_id   TEXT NOT NULL REFERENCES public.thavvu_points(id),
  kind              machine_payment_kind NOT NULL,
  amount            NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  payment_mode      TEXT,
  entry_method      TEXT,
  account_label     TEXT,
  notes             TEXT,
  hod_approved_at   TIMESTAMPTZ,
  hod_approved_by   UUID REFERENCES public.profiles(id),
  submitted_to_finance_at TIMESTAMPTZ,
  paid_at           TIMESTAMPTZ,
  paid_by           UUID REFERENCES public.profiles(id),
  payment_proof_path TEXT,
  registered_in_ids_book BOOLEAN DEFAULT false,
  status            machine_payment_status NOT NULL DEFAULT 'draft',
  created_by        UUID NOT NULL REFERENCES public.profiles(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_payment_requests_site ON public.machine_payment_requests(site_id);
CREATE INDEX idx_payment_requests_status ON public.machine_payment_requests(status);
CREATE INDEX idx_payment_requests_daily_log ON public.machine_payment_requests(daily_log_id);

CREATE TRIGGER trg_payment_requests_updated_at
  BEFORE UPDATE ON public.machine_payment_requests
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 12. MACHINE FINANCE REQUESTS
-- ============================================================
CREATE TYPE finance_request_status AS ENUM (
  'submitted', 'processing', 'paid', 'proof_uploaded', 'closed', 'rejected'
);

CREATE TABLE IF NOT EXISTS public.machine_finance_requests (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_request_id    UUID NOT NULL REFERENCES public.machine_payment_requests(id) ON DELETE CASCADE,
  site_id               TEXT NOT NULL REFERENCES public.sites(id),
  hod_id                UUID NOT NULL REFERENCES public.profiles(id),
  title                 TEXT NOT NULL,
  amount                NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  payment_mode          TEXT,
  account_label         TEXT,
  status                finance_request_status NOT NULL DEFAULT 'submitted',
  proof_path            TEXT,
  proof_uploaded_at     TIMESTAMPTZ,
  completed_at          TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_finance_requests_payment ON public.machine_finance_requests(payment_request_id);
CREATE INDEX idx_finance_requests_status ON public.machine_finance_requests(status);

CREATE TRIGGER trg_finance_requests_updated_at
  BEFORE UPDATE ON public.machine_finance_requests
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 13. MACHINE ATTACHMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.machine_attachments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_type    TEXT NOT NULL CHECK (reference_type IN (
    'machine_daily_log', 'payment_request', 'finance_request', 'machine_entry'
  )),
  reference_id      TEXT NOT NULL,
  file_type         TEXT NOT NULL CHECK (file_type IN ('image', 'pdf', 'video', 'other')),
  file_path         TEXT NOT NULL,
  file_name         TEXT,
  file_size         INTEGER,
  uploaded_by       UUID NOT NULL REFERENCES public.profiles(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_machine_attachments_ref ON public.machine_attachments(reference_type, reference_id);

-- ============================================================
-- 14. MACHINE AUDIT LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.machine_audit_logs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id           TEXT NOT NULL REFERENCES public.sites(id),
  thavvu_point_id   TEXT REFERENCES public.thavvu_points(id),
  actor_id          UUID NOT NULL REFERENCES public.profiles(id),
  action            TEXT NOT NULL,
  entity_type       TEXT NOT NULL,
  entity_id         TEXT NOT NULL,
  details           JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_site ON public.machine_audit_logs(site_id);
CREATE INDEX idx_audit_logs_actor ON public.machine_audit_logs(actor_id);
CREATE INDEX idx_audit_logs_entity ON public.machine_audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_created ON public.machine_audit_logs(created_at DESC);

-- Only allow inserts; never allow update/delete
CREATE POLICY "audit_logs_insert_only"
  ON public.machine_audit_logs FOR INSERT
  WITH CHECK (true);

CREATE POLICY "audit_logs_select_hod_finance_admin"
  ON public.machine_audit_logs FOR SELECT
  USING (
    public.has_role(ARRAY['hod', 'finance', 'admin'])
  );

-- ============================================================
-- 15. MODULE ALERTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.module_alerts (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id           TEXT NOT NULL REFERENCES public.sites(id),
  thavvu_point_id   TEXT REFERENCES public.thavvu_points(id),
  module            TEXT NOT NULL,
  alert_type        TEXT NOT NULL CHECK (alert_type IN (
    'info', 'warning', 'critical', 'success', 'revision'
  )),
  title             TEXT NOT NULL,
  message           TEXT,
  target_role       TEXT CHECK (target_role IN ('hod', 'supervisor', 'finance', 'admin', 'all')),
  target_profile_id UUID REFERENCES public.profiles(id),
  is_read           BOOLEAN NOT NULL DEFAULT false,
  link_entity_type  TEXT,
  link_entity_id    TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_module_alerts_target ON public.module_alerts(target_profile_id, is_read);
CREATE INDEX idx_module_alerts_role ON public.module_alerts(target_role, is_read);
CREATE INDEX idx_module_alerts_site ON public.module_alerts(site_id);

-- ============================================================
-- RLS — MACHINE TABLES
-- ============================================================
ALTER TABLE public.machine_suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.machine_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.machine_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.machine_daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.machine_daily_diesel_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.machine_payment_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.machine_finance_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.machine_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.machine_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.module_alerts ENABLE ROW LEVEL SECURITY;

-- Supervisors: read suppliers for their site
CREATE POLICY "suppliers_select_members"
  ON public.machine_suppliers FOR SELECT
  USING (
    site_id IN (SELECT site_id FROM public.site_memberships WHERE profile_id = auth.uid() AND is_active = true)
  );
CREATE POLICY "suppliers_insert_hod"
  ON public.machine_suppliers FOR INSERT
  WITH CHECK (public.has_role(ARRAY['hod', 'admin']));

-- Supervisors: read machines for their site
CREATE POLICY "assets_select_members"
  ON public.machine_assets FOR SELECT
  USING (
    site_id IN (SELECT site_id FROM public.site_memberships WHERE profile_id = auth.uid() AND is_active = true)
  );
CREATE POLICY "assets_insert_hod"
  ON public.machine_assets FOR INSERT
  WITH CHECK (public.has_role(ARRAY['hod', 'admin']));
CREATE POLICY "assets_update_hod"
  ON public.machine_assets FOR UPDATE
  USING (public.has_role(ARRAY['hod', 'admin']));

-- Assignments: supervisors see assigned machines; HOD sees all for their sites
CREATE POLICY "assignments_select_supervisor"
  ON public.machine_assignments FOR SELECT
  USING (
    thavvu_point_id IN (
      SELECT tp.id FROM public.thavvu_points tp
      JOIN public.thavvu_point_assignments tpa ON tpa.thavvu_point_id = tp.id
      WHERE tpa.supervisor_id = auth.uid() AND tpa.is_active = true
    )
    OR
    public.has_role(ARRAY['hod', 'admin'])
  );
CREATE POLICY "assignments_insert_hod"
  ON public.machine_assignments FOR INSERT
  WITH CHECK (public.has_role(ARRAY['hod', 'admin']));

-- Daily logs: supervisors submit/read own; HOD reads all for their sites
CREATE POLICY "daily_logs_select_supervisor"
  ON public.machine_daily_logs FOR SELECT
  USING (
    supervisor_id = auth.uid()
    OR
    EXISTS (SELECT 1 FROM public.site_memberships WHERE site_id = machine_daily_logs.site_id AND profile_id = auth.uid() AND is_active = true AND role IN ('hod', 'finance', 'admin'))
  );
CREATE POLICY "daily_logs_insert_supervisor"
  ON public.machine_daily_logs FOR INSERT
  WITH CHECK (supervisor_id = auth.uid());
CREATE POLICY "daily_logs_update_supervisor"
  ON public.machine_daily_logs FOR UPDATE
  USING (supervisor_id = auth.uid() AND status = 'draft');
CREATE POLICY "daily_logs_update_hod"
  ON public.machine_daily_logs FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships WHERE site_id = machine_daily_logs.site_id AND profile_id = auth.uid() AND is_active = true AND role IN ('hod', 'admin'))
  );

-- Payment requests: supervisors read own; HOD reads/approves; finance reads submitted
CREATE POLICY "payment_requests_select_supervisor"
  ON public.machine_payment_requests FOR SELECT
  USING (created_by = auth.uid());
CREATE POLICY "payment_requests_select_hod_finance"
  ON public.machine_payment_requests FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships WHERE site_id = machine_payment_requests.site_id AND profile_id = auth.uid() AND is_active = true AND role IN ('hod', 'finance', 'admin'))
  );
CREATE POLICY "payment_requests_insert_hod"
  ON public.machine_payment_requests FOR INSERT
  WITH CHECK (public.has_role(ARRAY['hod', 'admin']));
CREATE POLICY "payment_requests_update_hod"
  ON public.machine_payment_requests FOR UPDATE
  USING (public.has_role(ARRAY['hod', 'admin']));
CREATE POLICY "payment_requests_update_finance"
  ON public.machine_payment_requests FOR UPDATE
  USING (public.has_role(ARRAY['finance', 'admin']));

-- Finance requests: HOD creates/reads; finance reads/processes
CREATE POLICY "finance_requests_select_hod"
  ON public.machine_finance_requests FOR SELECT
  USING (
    hod_id = auth.uid()
    OR
    EXISTS (SELECT 1 FROM public.site_memberships WHERE site_id = machine_finance_requests.site_id AND profile_id = auth.uid() AND role IN ('finance', 'admin'))
  );
CREATE POLICY "finance_requests_insert_hod"
  ON public.machine_finance_requests FOR INSERT
  WITH CHECK (public.has_role(ARRAY['hod', 'admin']));
CREATE POLICY "finance_requests_update_finance"
  ON public.machine_finance_requests FOR UPDATE
  USING (public.has_role(ARRAY['finance', 'admin']));

-- Attachments: readers who can see the reference record
CREATE POLICY "attachments_select_related"
  ON public.machine_attachments FOR SELECT
  USING (true); -- application should validate context; for simpler access
CREATE POLICY "attachments_insert_owner"
  ON public.machine_attachments FOR INSERT
  WITH CHECK (uploaded_by = auth.uid());

-- Module alerts: see alerts targeted to you or your role
CREATE POLICY "alerts_select_related"
  ON public.module_alerts FOR SELECT
  USING (
    target_profile_id = auth.uid()
    OR
    target_role = (SELECT role FROM public.profiles WHERE id = auth.uid())
    OR
    target_role = 'all'
  );
CREATE POLICY "alerts_insert_hod"
  ON public.module_alerts FOR INSERT
  WITH CHECK (public.has_role(ARRAY['hod', 'admin']));
CREATE POLICY "alerts_update_read"
  ON public.module_alerts FOR UPDATE
  USING (target_profile_id = auth.uid() OR target_role = (SELECT role FROM public.profiles WHERE id = auth.uid()));
