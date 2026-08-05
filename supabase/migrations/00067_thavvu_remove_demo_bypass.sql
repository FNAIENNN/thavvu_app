-- ============================================================================
-- 00067_thavvu_remove_demo_bypass.sql
-- The demo-account bypass (is_demo_login) let the seeded demo HOD/supervisor
-- see EVERY tenant's data — a cross-tenant leak in the multi-tenant model.
-- Demo accounts are now normal tenants: hod@thavvu.com owns tenant 0001 and
-- is scoped exactly like any other HOD. All data isolation now flows purely
-- through is_same_tenant / membership checks.
-- ============================================================================

-- 1) is_same_tenant: no demo bypass.
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
      )
  );
$function$;

-- 2) is_point_member: no demo bypass (access flows through site membership).
CREATE OR REPLACE FUNCTION public.is_point_member(p_point_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.thavvu_points tp
    WHERE tp.id = p_point_id
      AND public.is_site_member(tp.site_id)
  );
$function$;

-- 3) Registration intake: HOD/admin only (no demo bypass).
DROP POLICY IF EXISTS requests_select_hod ON public.supervisor_registration_requests;
DROP POLICY IF EXISTS requests_update_hod ON public.supervisor_registration_requests;
CREATE POLICY requests_select_hod ON public.supervisor_registration_requests
  FOR SELECT
  USING (public.has_role(ARRAY['hod', 'admin']));
CREATE POLICY requests_update_hod ON public.supervisor_registration_requests
  FOR UPDATE
  USING (public.has_role(ARRAY['hod', 'admin']))
  WITH CHECK (public.has_role(ARRAY['hod', 'admin']));
