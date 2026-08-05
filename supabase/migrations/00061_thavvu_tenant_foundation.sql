-- ============================================================================
-- 00061_thavvu_tenant_foundation.sql
-- Multi-tenant foundation: HOD is the tenant.
--   * profiles.hod_id  -> owning HOD (NULL for HOD/admin accounts themselves)
--   * sites.hod_id     -> owning HOD (physical site owner)
--   * thavvu_points.hod_id -> owning HOD
--   * helpers: current_hod_id(), is_same_tenant()
--   * profiles RLS narrowed from "any HOD sees all profiles" to tenant scope
-- ============================================================================

-- 1) profiles.hod_id ---------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN hod_id UUID REFERENCES public.profiles(id);

-- 2) Tenant helper functions -------------------------------------------------
-- Returns the tenant id (owning HOD) for the authenticated user:
--   HOD/admin -> their own id; supervisor -> their HOD's id; else NULL.
CREATE OR REPLACE FUNCTION public.current_hod_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT CASE
    WHEN p.role IN ('hod', 'admin') THEN p.id
    ELSE p.hod_id
  END
  FROM public.profiles p
  WHERE p.id = auth.uid();
$function$;

-- True when the authenticated user belongs to the same tenant as p_hod_id.
-- HODs see their own tenant; supervisors see their HOD's tenant.
CREATE OR REPLACE FUNCTION public.is_same_tenant(p_hod_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles me
    WHERE me.id = auth.uid()
      AND (
        (me.role IN ('hod', 'admin') AND p_hod_id = me.id)
        OR (me.role = 'supervisor' AND me.hod_id IS NOT NULL AND p_hod_id = me.hod_id)
        OR public.is_demo_login()
      )
  );
$function$;

-- 3) Backfill existing supervisors -> their HOD ------------------------------
-- Priority: the HOD who assigned them via site membership; fallback to the
-- first HOD (single-tenant legacy data).
UPDATE public.profiles p
SET hod_id = COALESCE(
  (SELECT sm.assigned_by
     FROM public.site_memberships sm
    WHERE sm.profile_id = p.id
      AND sm.role = 'supervisor'
      AND sm.assigned_by IS NOT NULL
    ORDER BY sm.assigned_at DESC
    LIMIT 1),
  (SELECT id FROM public.profiles WHERE role = 'hod' ORDER BY created_at LIMIT 1)
)
WHERE p.role = 'supervisor'
  AND p.hod_id IS NULL;

-- 4) sites.hod_id (owning HOD) ----------------------------------------------
ALTER TABLE public.sites
  ADD COLUMN hod_id UUID REFERENCES public.profiles(id);

UPDATE public.sites s
SET hod_id = COALESCE(
  s.created_by,
  (SELECT sm.profile_id
     FROM public.site_memberships sm
    WHERE sm.site_id = s.id AND sm.role = 'hod' AND sm.is_active
    ORDER BY sm.assigned_at
    LIMIT 1),
  (SELECT id FROM public.profiles WHERE role = 'hod' ORDER BY created_at LIMIT 1)
)
WHERE s.hod_id IS NULL;

ALTER TABLE public.sites
  ALTER COLUMN hod_id SET NOT NULL;

-- 5) thavvu_points.hod_id (owning HOD via site) ------------------------------
ALTER TABLE public.thavvu_points
  ADD COLUMN hod_id UUID REFERENCES public.profiles(id);

UPDATE public.thavvu_points tp
SET hod_id = COALESCE(
  (SELECT s.hod_id FROM public.sites s WHERE s.id = tp.site_id),
  tp.created_by,
  (SELECT id FROM public.profiles WHERE role = 'hod' ORDER BY created_at LIMIT 1)
)
WHERE tp.hod_id IS NULL;

ALTER TABLE public.thavvu_points
  ALTER COLUMN hod_id SET NOT NULL;

-- 6) profiles RLS: tenant-scoped selection -----------------------------------
-- REMOVES the old policy that let ANY hod/finance/admin see ALL profiles.
DROP POLICY IF EXISTS profiles_select_hod_finance_admin ON public.profiles;
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;

-- Own profile always visible.
-- HOD/admin see the supervisors of their tenant (hod_id = me).
-- Supervisors see their own HOD's profile row (id = my hod_id).
CREATE POLICY profiles_select_tenant ON public.profiles
  FOR SELECT
  USING (
    auth.uid() = id
    OR (
      public.has_role(ARRAY['hod', 'admin'])
      AND hod_id = auth.uid()
    )
    OR (
      (SELECT p2.role FROM public.profiles p2 WHERE p2.id = auth.uid()) = 'supervisor'
      AND (
        hod_id = (SELECT p2.hod_id FROM public.profiles p2 WHERE p2.id = auth.uid())
        OR id = (SELECT p2.hod_id FROM public.profiles p2 WHERE p2.id = auth.uid())
      )
    )
  );

-- Users update only their own profile row; HOD account management for
-- supervisors goes through SECURITY DEFINER RPCs (admin_update_supervisor).
CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
