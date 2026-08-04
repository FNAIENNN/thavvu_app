-- ============================================================
-- Migration 00019: Supplier bills, supplier payment requests,
-- permanent-worker payment accounts + payment ledger with RLS,
-- and realtime publication for all of them.
-- ============================================================

-- ---------------------------------------------------------------------------
-- 1. supplier_bills — bill photos uploaded against suppliers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.supplier_bills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  supplier text NOT NULL,
  photo_path text,
  amount numeric(12, 2) NOT NULL DEFAULT 0,
  bill_date date NOT NULL DEFAULT current_date,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.supplier_bills ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supplier_bills_select_site_members" ON public.supplier_bills FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships
            WHERE site_id = supplier_bills.site_id AND profile_id = auth.uid() AND is_active = true)
    OR public.has_role(ARRAY['hod','admin','finance'])
  );
CREATE POLICY "supplier_bills_insert_members" ON public.supplier_bills FOR INSERT
  WITH CHECK (
    public.has_role(ARRAY['hod','supervisor','admin'])
    OR EXISTS (SELECT 1 FROM public.site_memberships
               WHERE site_id = supplier_bills.site_id AND profile_id = auth.uid() AND is_active = true)
  );
CREATE POLICY "supplier_bills_update_members" ON public.supplier_bills FOR UPDATE
  USING (
    public.has_role(ARRAY['hod','supervisor','admin'])
    OR EXISTS (SELECT 1 FROM public.site_memberships
               WHERE site_id = supplier_bills.site_id AND profile_id = auth.uid() AND is_active = true)
  );
CREATE POLICY "supplier_bills_delete_hod_admin" ON public.supplier_bills FOR DELETE
  USING (public.has_role(ARRAY['hod','admin']));

-- ---------------------------------------------------------------------------
-- 2. supplier_payment_requests — finance requests from the Supplier Bills tab
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.supplier_payment_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  supplier_name text NOT NULL,
  batch_ids text[] NOT NULL DEFAULT '{}',
  amount numeric(12, 2) NOT NULL DEFAULT 0,
  bill_amount numeric(12, 2) NOT NULL DEFAULT 0,
  used_amount numeric(12, 2) NOT NULL DEFAULT 0,
  request_type text NOT NULL DEFAULT 'Supplier Bill',
  method text NOT NULL DEFAULT 'UPI',
  status text NOT NULL DEFAULT 'Requested',
  payment_proof text,
  requested_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.supplier_payment_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supplier_payment_requests_select_site_members" ON public.supplier_payment_requests FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships
            WHERE site_id = supplier_payment_requests.site_id AND profile_id = auth.uid() AND is_active = true)
    OR public.has_role(ARRAY['hod','admin','finance'])
  );
CREATE POLICY "supplier_payment_requests_insert_members" ON public.supplier_payment_requests FOR INSERT
  WITH CHECK (
    public.has_role(ARRAY['hod','supervisor','admin'])
    OR EXISTS (SELECT 1 FROM public.site_memberships
               WHERE site_id = supplier_payment_requests.site_id AND profile_id = auth.uid() AND is_active = true)
  );
CREATE POLICY "supplier_payment_requests_update_members" ON public.supplier_payment_requests FOR UPDATE
  USING (
    public.has_role(ARRAY['hod','supervisor','admin'])
    OR EXISTS (SELECT 1 FROM public.site_memberships
               WHERE site_id = supplier_payment_requests.site_id AND profile_id = auth.uid() AND is_active = true)
  );
CREATE POLICY "supplier_payment_requests_delete_hod_admin" ON public.supplier_payment_requests FOR DELETE
  USING (public.has_role(ARRAY['hod','admin']));

-- ---------------------------------------------------------------------------
-- 3. payment_accounts — monthly salary accounts for permanent workers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  worker_id uuid REFERENCES public.workers(id) ON DELETE SET NULL,
  worker_name text NOT NULL,
  department text,
  days_worked integer NOT NULL DEFAULT 0,
  monthly_amount numeric(12, 2) NOT NULL DEFAULT 0,
  used_amount numeric(12, 2) NOT NULL DEFAULT 0,
  paid_amount numeric(12, 2) NOT NULL DEFAULT 0,
  is_paid boolean NOT NULL DEFAULT false,
  payment_month date NOT NULL,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- One account per worker per month per site.
CREATE UNIQUE INDEX IF NOT EXISTS payment_accounts_worker_month_idx
  ON public.payment_accounts (site_id, worker_id, payment_month)
  WHERE worker_id IS NOT NULL;

ALTER TABLE public.payment_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payment_accounts_select_site_members" ON public.payment_accounts FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships
            WHERE site_id = payment_accounts.site_id AND profile_id = auth.uid() AND is_active = true)
    OR public.has_role(ARRAY['hod','admin','finance'])
  );
CREATE POLICY "payment_accounts_insert_members" ON public.payment_accounts FOR INSERT
  WITH CHECK (
    public.has_role(ARRAY['hod','supervisor','admin'])
    OR EXISTS (SELECT 1 FROM public.site_memberships
               WHERE site_id = payment_accounts.site_id AND profile_id = auth.uid() AND is_active = true)
  );
CREATE POLICY "payment_accounts_update_members" ON public.payment_accounts FOR UPDATE
  USING (
    public.has_role(ARRAY['hod','supervisor','admin'])
    OR EXISTS (SELECT 1 FROM public.site_memberships
               WHERE site_id = payment_accounts.site_id AND profile_id = auth.uid() AND is_active = true)
  );
CREATE POLICY "payment_accounts_delete_hod_admin" ON public.payment_accounts FOR DELETE
  USING (public.has_role(ARRAY['hod','admin']));

-- ---------------------------------------------------------------------------
-- 4. payment_ledger — every used-amount / cash / request / reset entry
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  account_id uuid REFERENCES public.payment_accounts(id) ON DELETE CASCADE,
  worker_id uuid REFERENCES public.workers(id) ON DELETE SET NULL,
  worker_name text,
  type text NOT NULL,                 -- used_amount_cash / cash / used_amount_request / request / advance / month_reset / salary
  amount numeric(12, 2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'Pending',
  method text NOT NULL DEFAULT '',
  note text NOT NULL DEFAULT '',
  proof_id text,
  registered_in_machine_ids_book boolean NOT NULL DEFAULT false,
  entry_date timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payment_ledger_account_idx ON public.payment_ledger (account_id);
CREATE INDEX IF NOT EXISTS payment_ledger_site_idx ON public.payment_ledger (site_id, entry_date DESC);

ALTER TABLE public.payment_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payment_ledger_select_site_members" ON public.payment_ledger FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships
            WHERE site_id = payment_ledger.site_id AND profile_id = auth.uid() AND is_active = true)
    OR public.has_role(ARRAY['hod','admin','finance'])
  );
CREATE POLICY "payment_ledger_insert_members" ON public.payment_ledger FOR INSERT
  WITH CHECK (
    public.has_role(ARRAY['hod','supervisor','admin'])
    OR EXISTS (SELECT 1 FROM public.site_memberships
               WHERE site_id = payment_ledger.site_id AND profile_id = auth.uid() AND is_active = true)
  );
CREATE POLICY "payment_ledger_update_members" ON public.payment_ledger FOR UPDATE
  USING (
    public.has_role(ARRAY['hod','supervisor','admin'])
    OR EXISTS (SELECT 1 FROM public.site_memberships
               WHERE site_id = payment_ledger.site_id AND profile_id = auth.uid() AND is_active = true)
  );
CREATE POLICY "payment_ledger_delete_hod_admin" ON public.payment_ledger FOR DELETE
  USING (public.has_role(ARRAY['hod','admin']));

-- ---------------------------------------------------------------------------
-- 5. Realtime publication — add the new tables (idempotent)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'supplier_bills'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.supplier_bills';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'supplier_payment_requests'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.supplier_payment_requests';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'payment_accounts'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_accounts';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'payment_ledger'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.payment_ledger';
  END IF;
END;
$$;
