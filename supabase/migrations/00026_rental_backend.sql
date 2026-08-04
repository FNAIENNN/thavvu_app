-- ============================================================================
-- Migration 00026: Rental module — production backend.
--
-- 1. rental_catalogs      — vehicles/tools available for rental (HOD plans)
-- 2. rental_entries       — supervisor rental entries (with photos + fuel)
-- 3. rental_fuel_lines    — fuel consumed per entry
-- 4. rental_transfers     — internal transfers of rented assets
-- 5. rental_returns       — returns of rented assets
-- 6. rental_payments      — supplier payments for rentals
-- 7. rental-photos bucket — private photo storage (owner upload, site read)
--
-- Demo rows are flagged is_demo=true and are visible ONLY to the demo logins
-- (hod@thavvu.com / supervisor@thavvu.com) via public.is_demo_login().
-- Real rows (is_demo=false) are visible to active site members.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_demo_login()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.email IN ('hod@thavvu.com', 'supervisor@thavvu.com')
  );
$$;

CREATE OR REPLACE FUNCTION public.is_site_member(p_site_id text)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.site_memberships sm
    WHERE sm.site_id = p_site_id
      AND sm.profile_id = auth.uid()
      AND sm.is_active = true
  );
$$;

-- ---------------------------------------------------------------------------
-- 1. rental_catalogs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rental_catalogs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  name text NOT NULL,
  kind text NOT NULL DEFAULT 'vehicle' CHECK (kind IN ('vehicle', 'tool')),
  vehicle_number text,
  billing_type text NOT NULL DEFAULT 'DAY'
    CHECK (billing_type IN ('DAY', 'HOUR', 'TRIP', 'KM', 'WEEKLY')),
  rate_per_unit numeric(14, 2) NOT NULL DEFAULT 0,
  thavvu_ids text[] DEFAULT '{}',
  tank_ids text[] DEFAULT '{}',
  notes text,
  is_active boolean NOT NULL DEFAULT true,
  is_demo boolean NOT NULL DEFAULT false,
  created_by uuid NOT NULL REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rental_catalogs_site ON public.rental_catalogs(site_id);

-- ---------------------------------------------------------------------------
-- 2. rental_entries
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rental_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_no text NOT NULL,
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  catalog_id uuid REFERENCES public.rental_catalogs(id) ON DELETE SET NULL,
  vehicle_name text NOT NULL,
  billing_type text NOT NULL DEFAULT 'DAY'
    CHECK (billing_type IN ('DAY', 'HOUR', 'TRIP', 'KM', 'WEEKLY')),
  thavvu_id text,
  tank_id text,
  from_location text,
  to_location text,
  driver_or_operator text,
  work_date date NOT NULL DEFAULT CURRENT_DATE,
  units numeric(14, 2) NOT NULL DEFAULT 0,
  rate numeric(14, 2) NOT NULL DEFAULT 0,
  fuel_cost numeric(14, 2) NOT NULL DEFAULT 0,
  driver_bata numeric(14, 2) NOT NULL DEFAULT 0,
  loading_charge numeric(14, 2) NOT NULL DEFAULT 0,
  total_amount numeric(14, 2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('draft', 'submitted', 'approved', 'rejected', 'closed')),
  opening_photo_path text,
  bill_photo_path text,
  notes text,
  is_demo boolean NOT NULL DEFAULT false,
  created_by uuid NOT NULL REFERENCES public.profiles(id),
  hod_id uuid REFERENCES public.profiles(id),
  hod_note text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rental_entries_site ON public.rental_entries(site_id);
CREATE INDEX IF NOT EXISTS idx_rental_entries_status ON public.rental_entries(status);
CREATE INDEX IF NOT EXISTS idx_rental_entries_date ON public.rental_entries(work_date DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_rental_entries_no ON public.rental_entries(entry_no);

-- ---------------------------------------------------------------------------
-- 3. rental_fuel_lines
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rental_fuel_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id uuid NOT NULL REFERENCES public.rental_entries(id) ON DELETE CASCADE,
  fuel_type text NOT NULL DEFAULT 'Diesel',
  stock_point text,
  liters numeric(14, 2) NOT NULL DEFAULT 0,
  amount numeric(14, 2) NOT NULL DEFAULT 0,
  remarks text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rental_fuel_lines_entry ON public.rental_fuel_lines(entry_id);

-- ---------------------------------------------------------------------------
-- 4. rental_transfers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rental_transfers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_no text NOT NULL,
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  asset_kind text NOT NULL DEFAULT 'material' CHECK (asset_kind IN ('material', 'workEquipment')),
  item_name text NOT NULL,
  from_thavvu_id text,
  to_thavvu_id text,
  driver_or_operator text,
  work_date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'approved', 'rejected', 'closed')),
  photo_path text,
  notes text,
  is_demo boolean NOT NULL DEFAULT false,
  created_by uuid NOT NULL REFERENCES public.profiles(id),
  hod_id uuid REFERENCES public.profiles(id),
  hod_note text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rental_transfers_site ON public.rental_transfers(site_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_rental_transfers_no ON public.rental_transfers(transfer_no);

-- ---------------------------------------------------------------------------
-- 5. rental_returns
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rental_returns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  return_no text NOT NULL,
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  catalog_id uuid REFERENCES public.rental_catalogs(id) ON DELETE SET NULL,
  item_name text NOT NULL,
  from_thavvu_id text,
  work_date date NOT NULL DEFAULT CURRENT_DATE,
  quantity numeric(14, 2) NOT NULL DEFAULT 1,
  reason text,
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'approved', 'rejected', 'closed')),
  photo_path text,
  is_demo boolean NOT NULL DEFAULT false,
  created_by uuid NOT NULL REFERENCES public.profiles(id),
  hod_id uuid REFERENCES public.profiles(id),
  hod_note text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rental_returns_site ON public.rental_returns(site_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_rental_returns_no ON public.rental_returns(return_no);

-- ---------------------------------------------------------------------------
-- 6. rental_payments
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rental_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  supplier_name text NOT NULL,
  amount numeric(14, 2) NOT NULL DEFAULT 0,
  mode text NOT NULL DEFAULT 'cash' CHECK (mode IN ('cash', 'upi', 'bank', 'advance')),
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'approved', 'paid', 'rejected')),
  proof_path text,
  note text,
  is_demo boolean NOT NULL DEFAULT false,
  created_by uuid NOT NULL REFERENCES public.profiles(id),
  hod_id uuid REFERENCES public.profiles(id),
  hod_note text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rental_payments_site ON public.rental_payments(site_id);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.rental_catalogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rental_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rental_fuel_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rental_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rental_returns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rental_payments ENABLE ROW LEVEL SECURITY;

-- Catalogs: site members + demo logins see them; members can create.
DROP POLICY IF EXISTS "rental_catalogs_select" ON public.rental_catalogs;
CREATE POLICY "rental_catalogs_select" ON public.rental_catalogs FOR SELECT
  USING (public.is_site_member(site_id) OR public.is_demo_login());
DROP POLICY IF EXISTS "rental_catalogs_insert" ON public.rental_catalogs;
CREATE POLICY "rental_catalogs_insert" ON public.rental_catalogs FOR INSERT
  WITH CHECK (public.is_site_member(site_id));
DROP POLICY IF EXISTS "rental_catalogs_update" ON public.rental_catalogs;
CREATE POLICY "rental_catalogs_update" ON public.rental_catalogs FOR UPDATE
  USING (public.is_site_member(site_id));

-- Entries: site members + demo logins read; members create; creator updates own; HOD approves.
DROP POLICY IF EXISTS "rental_entries_select" ON public.rental_entries;
CREATE POLICY "rental_entries_select" ON public.rental_entries FOR SELECT
  USING (public.is_site_member(site_id) OR public.is_demo_login());
DROP POLICY IF EXISTS "rental_entries_insert" ON public.rental_entries;
CREATE POLICY "rental_entries_insert" ON public.rental_entries FOR INSERT
  WITH CHECK (public.is_site_member(site_id));
DROP POLICY IF EXISTS "rental_entries_update" ON public.rental_entries;
CREATE POLICY "rental_entries_update" ON public.rental_entries FOR UPDATE
  USING (
    (created_by = auth.uid() AND status IN ('draft', 'submitted'))
    OR public.has_role(ARRAY['hod', 'admin'])
  );

-- Fuel lines: readable via entry; site members insert.
DROP POLICY IF EXISTS "rental_fuel_lines_select" ON public.rental_fuel_lines;
CREATE POLICY "rental_fuel_lines_select" ON public.rental_fuel_lines FOR SELECT
  USING (true);
DROP POLICY IF EXISTS "rental_fuel_lines_insert" ON public.rental_fuel_lines;
CREATE POLICY "rental_fuel_lines_insert" ON public.rental_fuel_lines FOR INSERT
  WITH CHECK (entry_id IN (SELECT id FROM public.rental_entries WHERE public.is_site_member(site_id)));

-- Transfers / returns / payments: same membership pattern.
DROP POLICY IF EXISTS "rental_transfers_select" ON public.rental_transfers;
CREATE POLICY "rental_transfers_select" ON public.rental_transfers FOR SELECT
  USING (public.is_site_member(site_id) OR public.is_demo_login());
DROP POLICY IF EXISTS "rental_transfers_insert" ON public.rental_transfers;
CREATE POLICY "rental_transfers_insert" ON public.rental_transfers FOR INSERT
  WITH CHECK (public.is_site_member(site_id));
DROP POLICY IF EXISTS "rental_transfers_update" ON public.rental_transfers;
CREATE POLICY "rental_transfers_update" ON public.rental_transfers FOR UPDATE
  USING ((created_by = auth.uid() AND status IN ('submitted')) OR public.has_role(ARRAY['hod', 'admin']));

DROP POLICY IF EXISTS "rental_returns_select" ON public.rental_returns;
CREATE POLICY "rental_returns_select" ON public.rental_returns FOR SELECT
  USING (public.is_site_member(site_id) OR public.is_demo_login());
DROP POLICY IF EXISTS "rental_returns_insert" ON public.rental_returns;
CREATE POLICY "rental_returns_insert" ON public.rental_returns FOR INSERT
  WITH CHECK (public.is_site_member(site_id));
DROP POLICY IF EXISTS "rental_returns_update" ON public.rental_returns;
CREATE POLICY "rental_returns_update" ON public.rental_returns FOR UPDATE
  USING ((created_by = auth.uid() AND status IN ('submitted')) OR public.has_role(ARRAY['hod', 'admin']));

DROP POLICY IF EXISTS "rental_payments_select" ON public.rental_payments;
CREATE POLICY "rental_payments_select" ON public.rental_payments FOR SELECT
  USING (public.is_site_member(site_id) OR public.is_demo_login());
DROP POLICY IF EXISTS "rental_payments_insert" ON public.rental_payments;
CREATE POLICY "rental_payments_insert" ON public.rental_payments FOR INSERT
  WITH CHECK (public.is_site_member(site_id));
DROP POLICY IF EXISTS "rental_payments_update" ON public.rental_payments;
CREATE POLICY "rental_payments_update" ON public.rental_payments FOR UPDATE
  USING ((created_by = auth.uid() AND status IN ('submitted')) OR public.has_role(ARRAY['hod', 'admin']));

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'rental_catalogs') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rental_catalogs;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'rental_entries') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rental_entries;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'rental_fuel_lines') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rental_fuel_lines;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'rental_transfers') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rental_transfers;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'rental_returns') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rental_returns;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'rental_payments') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rental_payments;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Storage: rental-photos bucket (private; owner uploads, site members read)
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'rental-photos',
  'rental-photos',
  false,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "rental_photos_select" ON storage.objects;
CREATE POLICY "rental_photos_select" ON storage.objects FOR SELECT
  USING (bucket_id = 'rental-photos' AND (auth.role() = 'authenticated'));

DROP POLICY IF EXISTS "rental_photos_insert" ON storage.objects;
CREATE POLICY "rental_photos_insert" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'rental-photos'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "rental_photos_update" ON storage.objects;
CREATE POLICY "rental_photos_update" ON storage.objects FOR UPDATE
  USING (bucket_id = 'rental-photos' AND (storage.foldername(name))[1] = auth.uid()::text);

-- ---------------------------------------------------------------------------
-- Demo seed (visible only to demo logins via RLS is_demo gate)
-- ---------------------------------------------------------------------------
INSERT INTO public.rental_catalogs
  (site_id, name, kind, vehicle_number, billing_type, rate_per_unit, thavvu_ids, tank_ids, notes, is_demo, created_by)
SELECT
  'SITE-VJA-001', m.name, m.kind, m.vehicle_number, m.billing_type, m.rate,
  ARRAY['TP-VJA-001', 'TP-VJA-002'], ARRAY[]::text[], m.notes, true, p.id
FROM (VALUES
  ('JCB 3DX Backhoe', 'vehicle', 'AP39JC0001', 'DAY', 5200, 'Hydraulic excavator with operator'),
  ('Tata 407 Lorry', 'vehicle', 'AP39T0007', 'TRIP', 3800, 'Feed and material transport'),
  ('Tractor 45HP', 'vehicle', 'AP37TR4589', 'HOUR', 950, 'Bund work and haulage'),
  ('Diesel Bowser 2000L', 'vehicle', 'AP39BS0009', 'WEEKLY', 18000, 'On-site diesel supply'),
  ('Aerator Pump 2HP', 'tool', '', 'DAY', 450, 'Pond aeration equipment'),
  ('HDPE Net (100m)', 'tool', '', 'WEEKLY', 1200, 'Harvest and bird netting')
) AS m(name, kind, vehicle_number, billing_type, rate, notes)
CROSS JOIN LATERAL (
  SELECT id FROM public.profiles WHERE email = 'hod@thavvu.com' LIMIT 1
) p
ON CONFLICT DO NOTHING;

INSERT INTO public.rental_entries
  (entry_no, site_id, catalog_id, vehicle_name, billing_type, thavvu_id, tank_id,
   from_location, to_location, driver_or_operator, work_date, units, rate,
   fuel_cost, driver_bata, loading_charge, total_amount, status, notes, is_demo, created_by)
SELECT
  'RTL-DEMO-001', 'SITE-VJA-001', c.id, c.name, c.billing_type,
  'TP-VJA-001', NULL, 'Vijayawada Yard', 'East Ramp', 'Driver Mahesh',
  CURRENT_DATE - 1, 1, c.rate_per_unit, 0, 0, 0, c.rate_per_unit,
  'approved', 'Demo rental — JCB on bund repair (sample data)', true, p.id
FROM public.rental_catalogs c
CROSS JOIN LATERAL (
  SELECT id FROM public.profiles WHERE email = 'hod@thavvu.com' LIMIT 1
) p
WHERE c.name = 'JCB 3DX Backhoe' AND c.is_demo = true
ON CONFLICT DO NOTHING;
