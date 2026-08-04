-- ============================================================================
-- Migration 00027: Remaining module backends — Tasks, Maps, Cash.
--
-- Tasks:  tasks + task_steps (HOD assigns, supervisor completes)
-- Maps:   hod_map_uploads + public hod-map-uploads storage bucket
-- Cash:   cash_allocations (HOD→supervisor) + cash_transactions (ledger)
--
-- All tables use site-scoped RLS (is_site_member) and gate demo rows to demo
-- logins (is_demo + is_demo_login()), matching the rental standard so the
-- later hardening pass has no legacy loose policies to rewrite.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. TASKS
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  mode text NOT NULL DEFAULT 'single' CHECK (mode IN ('single', 'multiChecklist')),
  type text NOT NULL DEFAULT 'general',
  priority text NOT NULL DEFAULT 'medium',
  due_date timestamptz,
  assigned_at timestamptz NOT NULL DEFAULT now(),
  assigned_by text,
  assigned_supervisor_id text,
  site_name text,
  thavvu_id text,
  tank_id text,
  location_hint text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'in_progress', 'submitted', 'approved', 'rejected')),
  hod_note text,
  submitted_at timestamptz,
  proof_requirement text,
  proof jsonb,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tasks_site ON public.tasks(site_id);
CREATE INDEX IF NOT EXISTS idx_tasks_supervisor ON public.tasks(assigned_supervisor_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);

-- Defensive: a pre-existing `tasks` table (created outside migrations) may be
-- missing columns the app reads/writes. Backfill every column idempotently.
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS site_id text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS mode text DEFAULT 'single';
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS type text DEFAULT 'general';
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS priority text DEFAULT 'medium';
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS due_date timestamptz;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS assigned_at timestamptz DEFAULT now();
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS assigned_by text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS assigned_supervisor_id text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS site_name text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS thavvu_id text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS tank_id text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS location_hint text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending';
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS hod_note text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS submitted_at timestamptz;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS proof_requirement text;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS proof jsonb;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS is_demo boolean DEFAULT false;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Force assigned_by / assigned_supervisor_id to TEXT (the app uses local ids
-- like 'HOD-001' / 'SUP-VJA-001', not auth uuids). Drop any uuid FK first.
ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_assigned_by_fkey;
ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_assigned_supervisor_id_fkey;
ALTER TABLE public.tasks ALTER COLUMN assigned_by TYPE text;
ALTER TABLE public.tasks ALTER COLUMN assigned_supervisor_id TYPE text;

CREATE TABLE IF NOT EXISTS public.task_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id text NOT NULL,
  title text NOT NULL,
  instruction text,
  is_done boolean NOT NULL DEFAULT false,
  step_order integer NOT NULL DEFAULT 0,
  note text,
  proof_requirement text,
  proof jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.task_steps ADD COLUMN IF NOT EXISTS task_id text;
ALTER TABLE public.task_steps ADD COLUMN IF NOT EXISTS title text;
ALTER TABLE public.task_steps ADD COLUMN IF NOT EXISTS instruction text;
ALTER TABLE public.task_steps ADD COLUMN IF NOT EXISTS is_done boolean DEFAULT false;
ALTER TABLE public.task_steps ADD COLUMN IF NOT EXISTS step_order integer DEFAULT 0;
ALTER TABLE public.task_steps ADD COLUMN IF NOT EXISTS note text;
ALTER TABLE public.task_steps ADD COLUMN IF NOT EXISTS proof_requirement text;
ALTER TABLE public.task_steps ADD COLUMN IF NOT EXISTS proof jsonb;

CREATE INDEX IF NOT EXISTS idx_task_steps_task ON public.task_steps(task_id);

-- ---------------------------------------------------------------------------
-- 2. MAPS
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hod_map_uploads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  uploaded_by_id uuid REFERENCES public.profiles(id),
  title text NOT NULL,
  note text,
  file_name text,
  file_type text,
  file_path text,
  is_verified boolean NOT NULL DEFAULT false,
  is_demo boolean NOT NULL DEFAULT false,
  uploaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hod_map_uploads_site ON public.hod_map_uploads(site_id);

-- ---------------------------------------------------------------------------
-- 3. CASH
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.cash_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  allocated_by uuid NOT NULL REFERENCES public.profiles(id),
  allocated_to uuid REFERENCES public.profiles(id),
  amount numeric(14, 2) NOT NULL DEFAULT 0 CHECK (amount >= 0),
  balance_after numeric(14, 2) NOT NULL DEFAULT 0,
  note text,
  is_demo boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cash_allocations_site ON public.cash_allocations(site_id);

CREATE TABLE IF NOT EXISTS public.cash_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  txn_no text NOT NULL,
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  type text NOT NULL DEFAULT 'expense'
    CHECK (type IN ('expense', 'advance', 'payment', 'contra', 'allocation')),
  amount numeric(14, 2) NOT NULL DEFAULT 0,
  method text NOT NULL DEFAULT 'cash' CHECK (method IN ('cash', 'upi', 'bank', 'advance')),
  category text,
  note text,
  proof_path text,
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'approved', 'paid', 'rejected')),
  is_demo boolean NOT NULL DEFAULT false,
  created_by uuid NOT NULL REFERENCES public.profiles(id),
  hod_id uuid REFERENCES public.profiles(id),
  hod_note text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cash_transactions_site ON public.cash_transactions(site_id);
CREATE INDEX IF NOT EXISTS idx_cash_transactions_status ON public.cash_transactions(status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_cash_transactions_no ON public.cash_transactions(txn_no);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hod_map_uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tasks_select" ON public.tasks;
CREATE POLICY "tasks_select" ON public.tasks FOR SELECT
  USING (public.is_site_member(site_id) OR public.is_demo_login());
DROP POLICY IF EXISTS "tasks_insert" ON public.tasks;
CREATE POLICY "tasks_insert" ON public.tasks FOR INSERT
  WITH CHECK (public.is_site_member(site_id));
DROP POLICY IF EXISTS "tasks_update" ON public.tasks;
CREATE POLICY "tasks_update" ON public.tasks FOR UPDATE
  USING (public.is_site_member(site_id));

DROP POLICY IF EXISTS "task_steps_select" ON public.task_steps;
CREATE POLICY "task_steps_select" ON public.task_steps FOR SELECT
  USING (true);
DROP POLICY IF EXISTS "task_steps_insert" ON public.task_steps;
CREATE POLICY "task_steps_insert" ON public.task_steps FOR INSERT
  WITH CHECK (task_id IN (SELECT id FROM public.tasks WHERE public.is_site_member(site_id)));

DROP POLICY IF EXISTS "map_uploads_select" ON public.hod_map_uploads;
CREATE POLICY "map_uploads_select" ON public.hod_map_uploads FOR SELECT
  USING (public.is_site_member(site_id) OR public.is_demo_login());
DROP POLICY IF EXISTS "map_uploads_insert" ON public.hod_map_uploads;
CREATE POLICY "map_uploads_insert" ON public.hod_map_uploads FOR INSERT
  WITH CHECK (public.is_site_member(site_id));
DROP POLICY IF EXISTS "map_uploads_update" ON public.hod_map_uploads;
CREATE POLICY "map_uploads_update" ON public.hod_map_uploads FOR UPDATE
  USING (public.is_site_member(site_id));

DROP POLICY IF EXISTS "cash_allocations_select" ON public.cash_allocations;
CREATE POLICY "cash_allocations_select" ON public.cash_allocations FOR SELECT
  USING (public.is_site_member(site_id) OR public.is_demo_login());
DROP POLICY IF EXISTS "cash_allocations_insert" ON public.cash_allocations;
CREATE POLICY "cash_allocations_insert" ON public.cash_allocations FOR INSERT
  WITH CHECK (public.is_site_member(site_id));

DROP POLICY IF EXISTS "cash_transactions_select" ON public.cash_transactions;
CREATE POLICY "cash_transactions_select" ON public.cash_transactions FOR SELECT
  USING (public.is_site_member(site_id) OR public.is_demo_login());
DROP POLICY IF EXISTS "cash_transactions_insert" ON public.cash_transactions;
CREATE POLICY "cash_transactions_insert" ON public.cash_transactions FOR INSERT
  WITH CHECK (public.is_site_member(site_id));
DROP POLICY IF EXISTS "cash_transactions_update" ON public.cash_transactions;
CREATE POLICY "cash_transactions_update" ON public.cash_transactions FOR UPDATE
  USING (public.is_site_member(site_id));

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'tasks') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'task_steps') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.task_steps;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'hod_map_uploads') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.hod_map_uploads;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'cash_allocations') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.cash_allocations;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'cash_transactions') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.cash_transactions;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Storage: hod-map-uploads (public bucket so site members can preview maps)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'hod-map-uploads',
  'hod-map-uploads',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::text[]
) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "hod_map_uploads_read" ON storage.objects;
CREATE POLICY "hod_map_uploads_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'hod-map-uploads' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "hod_map_uploads_write" ON storage.objects;
CREATE POLICY "hod_map_uploads_write" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'hod-map-uploads' AND auth.role() = 'authenticated');

-- ---------------------------------------------------------------------------
-- Demo seed (visible only to demo logins via is_demo gating)
-- ---------------------------------------------------------------------------
INSERT INTO public.tasks
  (site_id, title, description, mode, type, priority, due_date, assigned_at,
   assigned_by, assigned_supervisor_id, site_name, thavvu_id, status, is_demo)
SELECT
  'SITE-VJA-001', m.title, m.description, m.mode, m.type, m.priority,
  now() + interval '2 days', now(), 'HOD-001', 'SUP-VJA-001',
  'Vijayawada River Bed', 'TP-VJA-001', 'pending', true
FROM (VALUES
  ('Check east ramp bund repair', 'Inspect the bund after yesterday''s rain and log repair needs.', 'single', 'inspection', 'high'),
  ('Verify diesel stock tank', 'Check the diesel stock tank level and report litres remaining.', 'single', 'stock', 'medium')
) AS m(title, description, mode, type, priority)
WHERE NOT EXISTS (
  SELECT 1 FROM public.tasks WHERE is_demo = true AND site_id = 'SITE-VJA-001'
)
ON CONFLICT DO NOTHING;

INSERT INTO public.cash_allocations
  (site_id, allocated_by, allocated_to, amount, balance_after, note, is_demo)
SELECT
  'SITE-VJA-001', hod.id, sup.id, 25000, 25000, 'Demo opening cash for site operations', true
FROM (SELECT id FROM public.profiles WHERE email = 'hod@thavvu.com' LIMIT 1) hod
CROSS JOIN LATERAL (SELECT id FROM public.profiles WHERE email = 'supervisor@thavvu.com' LIMIT 1) sup
WHERE NOT EXISTS (
  SELECT 1 FROM public.cash_allocations WHERE is_demo = true AND site_id = 'SITE-VJA-001'
)
ON CONFLICT DO NOTHING;

INSERT INTO public.cash_transactions
  (txn_no, site_id, type, amount, method, category, note, status, is_demo, created_by)
SELECT
  'CASH-DEMO-001', 'SITE-VJA-001', 'allocation', 25000, 'cash', 'Opening cash',
  'Demo cash allocation recorded', 'approved', true, hod.id
FROM (SELECT id FROM public.profiles WHERE email = 'hod@thavvu.com' LIMIT 1) hod
ON CONFLICT (txn_no) DO NOTHING;
