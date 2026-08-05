-- ============================================================================
-- Migration 00056: Diagnostic function for the approval point-assignment bug.
-- Replicates the site/point resolution logic of approve_supervisor_registration
-- inside an identical SECURITY DEFINER context so we can see which step fails.
-- Dropped by 00057 after diagnosis.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.diag_approve_point(p_site_id text, p_supervisor_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, auth
AS $$
DECLARE
  v_site_ok  boolean := false;
  v_point_id text;
  v_membership_count int;
  v_inserted  boolean := false;
  v_insert_error text;
BEGIN
  IF p_site_id IS NOT NULL AND p_site_id <> '' THEN
    SELECT EXISTS (SELECT 1 FROM public.sites WHERE id = p_site_id) INTO v_site_ok;
  END IF;

  IF v_site_ok THEN
    SELECT id INTO v_point_id
    FROM public.thavvu_points
    WHERE site_id = p_site_id
      AND status IN ('active', 'granted')
    ORDER BY created_at
    LIMIT 1;
  END IF;

  SELECT count(*)::int INTO v_membership_count
  FROM public.site_memberships WHERE site_id = p_site_id;

  -- Replicate the exact assignment insert (when a supervisor id is given).
  IF p_supervisor_id IS NOT NULL AND v_point_id IS NOT NULL THEN
    BEGIN
      INSERT INTO public.thavvu_point_assignments
        (id, thavvu_point_id, supervisor_id, site_id, assigned_by, is_active, assigned_at)
      VALUES
        (gen_random_uuid(), v_point_id, p_supervisor_id, p_site_id, auth.uid(), true, now())
      ON CONFLICT DO NOTHING;
      v_inserted := true;
    EXCEPTION WHEN OTHERS THEN
      v_insert_error := SQLERRM;
    END;
  END IF;

  RETURN jsonb_build_object(
    'site_ok', v_site_ok,
    'point_id', v_point_id,
    'membership_count', v_membership_count,
    'inserted', v_inserted,
    'insert_error', v_insert_error);
END $$;

REVOKE ALL ON FUNCTION public.diag_approve_point(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.diag_approve_point(text, uuid) TO authenticated;
