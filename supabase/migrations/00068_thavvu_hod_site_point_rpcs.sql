-- ============================================================================
-- 00068: HOD workspace — tenant-scoped site / thavvu-point creation & grant
-- ============================================================================
-- Completes the enterprise loop: the HOD "Create Site", "Create Thavvu Point"
-- and "Grant" screens previously wrote ONLY to device-local SharedPreferences.
-- These SECURITY DEFINER RPCs create REAL rows (sites / thavvu_points /
-- thavvu_point_assignments / site_memberships) inside the caller's tenant.
--
-- Tenant rules (same as admin_create_supervisor, 00063):
--   * caller must be an authenticated hod/admin
--   * every referenced object (site, point, supervisor) is validated to belong
--     to the caller's department BEFORE any write
--   * hod_id is stamped by the existing BEFORE INSERT triggers
--     (trg_sites_hod_id / trg_thavvu_points_hod_id), so RLS bypass via
--     SECURITY DEFINER cannot forge a tenant
-- ============================================================================

-- 1) admin_create_site -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_create_site(
  p_name text,
  p_place text,
  p_admin_name text,
  p_acres numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_prefix text;
  v_id     text;
  v_seq    int;
BEGIN
  -- 1) Guard: authenticated HOD/admin only.
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF NOT public.has_role(ARRAY['hod', 'admin']) THEN
    RAISE EXCEPTION 'Only HOD accounts can create sites';
  END IF;

  -- 2) Input validation (mirrors the UI validators).
  IF length(trim(p_name)) < 3 THEN
    RAISE EXCEPTION 'Enter a valid site name';
  END IF;
  IF length(trim(p_place)) < 2 THEN
    RAISE EXCEPTION 'Enter a valid site place';
  END IF;
  IF length(trim(p_admin_name)) < 3 THEN
    RAISE EXCEPTION 'Enter the site admin name';
  END IF;
  IF p_acres IS NULL OR p_acres <= 0 THEN
    RAISE EXCEPTION 'Site acres must be greater than zero';
  END IF;

  -- 3) Per-tenant duplicate guard (two HODs may both name a site "River Bed").
  IF EXISTS (
    SELECT 1 FROM public.sites
    WHERE lower(name) = lower(trim(p_name)) AND hod_id = v_caller
  ) THEN
    RAISE EXCEPTION 'This site already exists';
  END IF;

  -- 4) Human-readable id: SITE-<first 3 letters of place>-NNN.
  v_prefix := upper(left(
    coalesce(regexp_replace(trim(p_place), '[^a-zA-Z]', '', 'g'), ''), 3));
  IF length(v_prefix) < 3 THEN
    v_prefix := 'XXX';
  END IF;

  v_seq := 1;
  LOOP
    v_id := 'SITE-' || v_prefix || '-' || lpad(v_seq::text, 3, '0');
    BEGIN
      INSERT INTO public.sites
        (id, name, place, admin_name, acres, status, created_by)
      VALUES
        (v_id, trim(p_name), trim(p_place), trim(p_admin_name), p_acres,
         'active', v_caller);
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_seq := v_seq + 1;
      IF v_seq > 9999 THEN
        RAISE EXCEPTION 'Could not allocate a site id';
      END IF;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'id', v_id,
    'name', trim(p_name),
    'place', trim(p_place),
    'admin_name', trim(p_admin_name),
    'acres', p_acres,
    'status', 'active',
    'created_at', now()
  );
END;
$function$;

-- 2) admin_create_thavvu_point ----------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_create_thavvu_point(
  p_site_id text,
  p_point_name text,
  p_assigned_acres numeric,
  p_supervisor_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller   uuid := auth.uid();
  v_site_hod uuid;
  v_place    text;
  v_prefix   text;
  v_id       text;
  v_seq      int;
BEGIN
  -- 1) Guard: authenticated HOD/admin only.
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF NOT public.has_role(ARRAY['hod', 'admin']) THEN
    RAISE EXCEPTION 'Only HOD accounts can create Thavvu Points';
  END IF;

  -- 2) TENANT: the site must belong to the caller's department.
  SELECT s.hod_id, s.place INTO v_site_hod, v_place
    FROM public.sites s
   WHERE s.id = p_site_id;
  IF v_site_hod IS NULL OR v_site_hod <> v_caller THEN
    RAISE EXCEPTION 'Site not found in your department';
  END IF;

  -- 3) TENANT: the supervisor must be the caller's own supervisor.
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = p_supervisor_id
      AND p.role = 'supervisor'
      AND p.hod_id = v_caller
  ) THEN
    RAISE EXCEPTION 'Supervisor not found in your department';
  END IF;

  -- 4) Input validation (mirrors the UI validators).
  IF length(trim(p_point_name)) < 3 THEN
    RAISE EXCEPTION 'Enter a valid Thavvu Point name';
  END IF;
  IF p_assigned_acres IS NULL OR p_assigned_acres <= 0 THEN
    RAISE EXCEPTION 'Supervisor acres must be greater than zero';
  END IF;
  IF p_assigned_acres > (SELECT acres FROM public.sites WHERE id = p_site_id) THEN
    RAISE EXCEPTION 'Supervisor acres cannot exceed site acres';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.thavvu_points
    WHERE site_id = p_site_id
      AND lower(point_name) = lower(trim(p_point_name))
  ) THEN
    RAISE EXCEPTION 'This Thavvu Point already exists for the selected site';
  END IF;

  -- 5) Human-readable id: TP-<first 3 letters of site place>-NNN.
  v_prefix := upper(left(
    coalesce(regexp_replace(trim(v_place), '[^a-zA-Z]', '', 'g'), ''), 3));
  IF length(v_prefix) < 3 THEN
    v_prefix := 'XXX';
  END IF;

  v_seq := 1;
  LOOP
    v_id := 'TP-' || v_prefix || '-' || lpad(v_seq::text, 3, '0');
    BEGIN
      INSERT INTO public.thavvu_points
        (id, site_id, point_name, assigned_acres, status, created_by)
      VALUES
        (v_id, p_site_id, trim(p_point_name), p_assigned_acres, 'draft',
         v_caller);
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_seq := v_seq + 1;
      IF v_seq > 9999 THEN
        RAISE EXCEPTION 'Could not allocate a Thavvu Point id';
      END IF;
    END;
  END LOOP;

  -- 6) Link the supervisor now (enterprise graph): active assignment +
  --    site membership, same shape as admin_create_supervisor step 9.
  INSERT INTO public.thavvu_point_assignments
    (id, thavvu_point_id, supervisor_id, site_id, assigned_by, is_active,
     assigned_at)
  VALUES
    (gen_random_uuid(), v_id, p_supervisor_id, p_site_id, v_caller, true, now())
  ON CONFLICT DO NOTHING;

  INSERT INTO public.site_memberships
    (id, site_id, profile_id, role, is_active, assigned_by, assigned_at)
  VALUES
    (gen_random_uuid(), p_site_id, p_supervisor_id, 'supervisor', true,
     v_caller, now())
  ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object(
    'id', v_id,
    'site_id', p_site_id,
    'point_name', trim(p_point_name),
    'assigned_acres', p_assigned_acres,
    'status', 'draft',
    'supervisor_id', p_supervisor_id::text,
    'created_at', now()
  );
END;
$function$;

-- 3) admin_grant_thavvu_point ------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_grant_thavvu_point(p_point_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller   uuid := auth.uid();
  v_point_hod uuid;
  v_status   text;
BEGIN
  -- 1) Guard: authenticated HOD/admin only.
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF NOT public.has_role(ARRAY['hod', 'admin']) THEN
    RAISE EXCEPTION 'Only HOD accounts can grant Thavvu Points';
  END IF;

  -- 2) TENANT: the point must belong to the caller's department.
  SELECT tp.hod_id, tp.status INTO v_point_hod, v_status
    FROM public.thavvu_points tp
   WHERE tp.id = p_point_id;
  IF v_point_hod IS NULL OR v_point_hod <> v_caller THEN
    RAISE EXCEPTION 'Point not found in your department';
  END IF;

  -- 3) Idempotent: already granted/active points stay as-is.
  IF v_status IN ('granted', 'active') THEN
    RETURN jsonb_build_object(
      'id', p_point_id,
      'status', v_status,
      'already_granted', true
    );
  END IF;

  UPDATE public.thavvu_points
     SET status = 'granted',
         granted_at = now(),
         granted_by = v_caller
   WHERE id = p_point_id;

  RETURN jsonb_build_object(
    'id', p_point_id,
    'status', 'granted',
    'granted_at', now(),
    'already_granted', false
  );
END;
$function$;
