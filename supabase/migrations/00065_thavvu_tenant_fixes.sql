-- ============================================================================
-- 00065_thavvu_tenant_fixes.sql
-- Fixes found by live verification:
--   1) profiles policy recursed on itself (same-table subquery in RLS).
--      Replaced with SECURITY DEFINER helpers (my_role/my_hod_id).
--   2) sites → site_memberships → sites RLS recursion. is_site_member is
--      now SECURITY DEFINER so membership lookups bypass RLS (matching the
--      is_same_tenant / is_point_member pattern) and cannot recurse.
--   3) sites.created_by is NOT NULL — new trigger stamps it + hod_id so a
--      HOD can create their own site from the app.
-- ============================================================================

-- 1) Definer helpers for RLS (query profiles with RLS bypass -> no recursion).
CREATE OR REPLACE FUNCTION public.my_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.my_hod_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT hod_id FROM public.profiles WHERE id = auth.uid();
$function$;

-- 2) is_site_member must bypass RLS (definer) to break the sites <-> memberships
--    policy recursion.
ALTER FUNCTION public.is_site_member(text) SECURITY DEFINER;

-- 3) Rebuild the profiles SELECT policy without same-table subqueries.
DROP POLICY IF EXISTS profiles_select_tenant ON public.profiles;
CREATE POLICY profiles_select_tenant ON public.profiles
  FOR SELECT
  USING (
    auth.uid() = id
    OR (
      public.has_role(ARRAY['hod', 'admin'])
      AND hod_id = auth.uid()
    )
    OR (
      public.my_role() = 'supervisor'
      AND (hod_id = public.my_hod_id() OR id = public.my_hod_id())
    )
  );

-- 4) sites: stamp hod_id AND created_by so HOD-created sites satisfy the
--    NOT NULL columns.
DROP TRIGGER IF EXISTS trg_sites_hod_id ON public.sites;
CREATE OR REPLACE FUNCTION public.trg_sites_stamp()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.hod_id := COALESCE(NEW.hod_id, public.current_hod_id());
  NEW.created_by := COALESCE(NEW.created_by, auth.uid());
  RETURN NEW;
END;
$function$;
CREATE TRIGGER trg_sites_stamp BEFORE INSERT ON public.sites
  FOR EACH ROW EXECUTE FUNCTION public.trg_sites_stamp();
