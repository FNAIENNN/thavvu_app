-- ============================================================================
-- 00070: cash finance requests (supervisor -> HOD review)
--
-- Finance requests were only ever stored locally (SharedPreferences), so
-- HOD never saw them. A dedicated table avoids the cash_transactions
-- type CHECK constraint (which only allows expense/advance/payment/contra/
-- allocation) and gives HOD a clean review queue.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.cash_finance_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_no text NOT NULL,
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  thavvu_point_id text,
  type text NOT NULL DEFAULT 'expense',
  amount numeric(14, 2) NOT NULL DEFAULT 0,
  category text,
  reason text,
  payment_method text NOT NULL DEFAULT 'upi'
    CHECK (payment_method IN ('upi', 'bank', 'cash')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  proof_path text,
  voice_path text,
  requested_by uuid NOT NULL REFERENCES public.profiles(id),
  hod_id uuid REFERENCES public.profiles(id),
  hod_note text,
  reviewed_at timestamptz,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cash_finance_requests_site
  ON public.cash_finance_requests(site_id);
CREATE INDEX IF NOT EXISTS idx_cash_finance_requests_status
  ON public.cash_finance_requests(status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_cash_finance_requests_no
  ON public.cash_finance_requests(request_no);

-- Tenant isolation: hod_id is stamped from the calling profile on insert.
ALTER TABLE public.cash_finance_requests ADD COLUMN IF NOT EXISTS hod_id uuid
  REFERENCES public.profiles(id);
ALTER TABLE public.cash_finance_requests ALTER COLUMN hod_id SET NOT NULL;
CREATE TRIGGER trg_cash_finance_requests_hod_id
  BEFORE INSERT ON public.cash_finance_requests
  FOR EACH ROW EXECUTE FUNCTION public.trg_stamp_hod_id();

ALTER TABLE public.cash_finance_requests ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE rec RECORD; BEGIN
  FOR rec IN SELECT polname FROM pg_policy
             WHERE polrelid = 'public.cash_finance_requests'::regclass LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.cash_finance_requests', rec.polname);
  END LOOP;
END $$;

CREATE POLICY cash_finance_requests_tenant_select ON public.cash_finance_requests FOR SELECT
  USING (public.is_same_tenant(hod_id));
CREATE POLICY cash_finance_requests_tenant_insert ON public.cash_finance_requests FOR INSERT
  WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY cash_finance_requests_tenant_update ON public.cash_finance_requests FOR UPDATE
  USING (public.is_same_tenant(hod_id)) WITH CHECK (public.is_same_tenant(hod_id));
CREATE POLICY cash_finance_requests_tenant_delete ON public.cash_finance_requests FOR DELETE
  USING (public.is_same_tenant(hod_id));

-- Realtime so the HOD review queue updates live.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime'
                   AND schemaname = 'public'
                   AND tablename = 'cash_finance_requests') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.cash_finance_requests;
  END IF;
END $$;
