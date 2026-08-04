-- Thavvu App: Identity, Sites, Thavvu Points & Assignments
-- This migration establishes the role-based relationship hierarchy:
--   Auth Users → Profiles → Sites → Thavvu Points → Supervisor Assignments

-- ============================================================
-- 1. PROFILES (linked to auth.users)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  emp_id      TEXT UNIQUE NOT NULL,
  full_name   TEXT NOT NULL,
  email       TEXT,
  phone       TEXT,
  role        TEXT NOT NULL CHECK (role IN ('hod', 'supervisor', 'finance', 'admin')),
  avatar_url  TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_emp_id ON public.profiles(emp_id);

-- Auto-create profile on auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, emp_id, full_name, email, role, is_active)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'emp_id', NEW.id::text),
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'supervisor'),
    true
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Sync updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 2. SITES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.sites (
  id            TEXT PRIMARY KEY,  -- e.g. SITE-VJA-001
  name          TEXT NOT NULL,
  place         TEXT NOT NULL,
  admin_name    TEXT,
  acres         NUMERIC(10,2) NOT NULL DEFAULT 0,
  status        TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
  created_by    UUID NOT NULL REFERENCES public.profiles(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sites_place ON public.sites(place);
CREATE INDEX idx_sites_status ON public.sites(status);

CREATE TRIGGER trg_sites_updated_at
  BEFORE UPDATE ON public.sites
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 3. THAVVU POINTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.thavvu_points (
  id            TEXT PRIMARY KEY,  -- e.g. TP-VJA-001
  site_id       TEXT NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  point_name    TEXT NOT NULL,
  assigned_acres NUMERIC(10,2) NOT NULL DEFAULT 0,
  status        TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'granted', 'active', 'inactive', 'archived')),
  created_by    UUID NOT NULL REFERENCES public.profiles(id),
  granted_at    TIMESTAMPTZ,
  granted_by    UUID REFERENCES public.profiles(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_thavvu_points_site ON public.thavvu_points(site_id);
CREATE INDEX idx_thavvu_points_status ON public.thavvu_points(status);

CREATE TRIGGER trg_thavvu_points_updated_at
  BEFORE UPDATE ON public.thavvu_points
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 4. SITE MEMBERSHIPS (role-based access to sites)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.site_memberships (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id       TEXT NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  profile_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role          TEXT NOT NULL CHECK (role IN ('hod', 'supervisor', 'finance', 'admin')),
  is_active     BOOLEAN NOT NULL DEFAULT true,
  assigned_by   UUID REFERENCES public.profiles(id),
  assigned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at      TIMESTAMPTZ,
  UNIQUE(site_id, profile_id, role, ended_at)
);

CREATE INDEX idx_site_memberships_profile ON public.site_memberships(profile_id);
CREATE INDEX idx_site_memberships_site_role ON public.site_memberships(site_id, role);

-- ============================================================
-- 5. THAVVU POINT ASSIGNMENTS (supervisor reassignment history)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.thavvu_point_assignments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thavvu_point_id   TEXT NOT NULL REFERENCES public.thavvu_points(id) ON DELETE CASCADE,
  supervisor_id     UUID NOT NULL REFERENCES public.profiles(id),
  site_id           TEXT NOT NULL REFERENCES public.sites(id) ON DELETE CASCADE,
  assigned_by       UUID NOT NULL REFERENCES public.profiles(id),  -- HOD who assigned
  is_active         BOOLEAN NOT NULL DEFAULT true,
  assigned_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at          TIMESTAMPTZ,
  reason            TEXT
);

-- Partial unique index: only one ACTIVE assignment per Thavvu Point.
CREATE UNIQUE INDEX idx_tp_assignments_active_unique
  ON public.thavvu_point_assignments(thavvu_point_id)
  WHERE is_active = true;

CREATE INDEX idx_tp_assignments_supervisor ON public.thavvu_point_assignments(supervisor_id, is_active);
CREATE INDEX idx_tp_assignments_point ON public.thavvu_point_assignments(thavvu_point_id);

-- ============================================================
-- ROLE CHECK HELPER
-- Runs with SECURITY DEFINER so it bypasses RLS on profiles.
-- Prevents "infinite recursion detected in policy for relation profiles"
-- that occurs when a policy on profiles subqueries profiles directly.
-- ============================================================
CREATE OR REPLACE FUNCTION public.has_role(roles TEXT[])
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = ANY(roles)
  );
$$;

-- ============================================================
-- RLS — PROFILES
-- ============================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "profiles_select_hod_finance_admin"
  ON public.profiles FOR SELECT
  USING (
    public.has_role(ARRAY['hod', 'finance', 'admin'])
  );

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================
-- RLS — SITES
-- ============================================================
ALTER TABLE public.sites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sites_select_members"
  ON public.sites FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships WHERE site_id = sites.id AND profile_id = auth.uid() AND is_active = true)
    OR
    public.has_role(ARRAY['hod', 'admin'])
  );

CREATE POLICY "sites_insert_hod_admin"
  ON public.sites FOR INSERT
  WITH CHECK (
    public.has_role(ARRAY['hod', 'admin'])
  );

CREATE POLICY "sites_update_hod_admin"
  ON public.sites FOR UPDATE
  USING (
    public.has_role(ARRAY['hod', 'admin'])
  );

-- ============================================================
-- RLS — THAVVU POINTS
-- ============================================================
ALTER TABLE public.thavvu_points ENABLE ROW LEVEL SECURITY;

CREATE POLICY "thavvu_points_select_members"
  ON public.thavvu_points FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships WHERE site_id = thavvu_points.site_id AND profile_id = auth.uid() AND is_active = true)
    OR
    public.has_role(ARRAY['hod', 'admin'])
  );

CREATE POLICY "thavvu_points_insert_hod_admin"
  ON public.thavvu_points FOR INSERT
  WITH CHECK (
    public.has_role(ARRAY['hod', 'admin'])
  );

CREATE POLICY "thavvu_points_update_hod_admin"
  ON public.thavvu_points FOR UPDATE
  USING (
    public.has_role(ARRAY['hod', 'admin'])
  );

-- ============================================================
-- RLS — SITE MEMBERSHIPS
-- ============================================================
ALTER TABLE public.site_memberships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "site_memberships_select_own"
  ON public.site_memberships FOR SELECT
  USING (profile_id = auth.uid());

CREATE POLICY "site_memberships_select_hod_admin"
  ON public.site_memberships FOR SELECT
  USING (
    public.has_role(ARRAY['hod', 'admin'])
  );

CREATE POLICY "site_memberships_insert_hod_admin"
  ON public.site_memberships FOR INSERT
  WITH CHECK (
    public.has_role(ARRAY['hod', 'admin'])
  );

-- ============================================================
-- RLS — THAVVU POINT ASSIGNMENTS
-- ============================================================
ALTER TABLE public.thavvu_point_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tp_assignments_select_related"
  ON public.thavvu_point_assignments FOR SELECT
  USING (
    supervisor_id = auth.uid()
    OR
    public.has_role(ARRAY['hod', 'admin', 'finance'])
  );

CREATE POLICY "tp_assignments_insert_hod_admin"
  ON public.thavvu_point_assignments FOR INSERT
  WITH CHECK (
    public.has_role(ARRAY['hod', 'admin'])
  );

CREATE POLICY "tp_assignments_update_hod_admin"
  ON public.thavvu_point_assignments FOR UPDATE
  USING (
    public.has_role(ARRAY['hod', 'admin'])
  );
