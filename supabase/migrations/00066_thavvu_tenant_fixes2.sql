-- ============================================================================
-- 00066_thavvu_tenant_fixes2.sql
-- thavvu_points.created_by is NOT NULL — stamp it (plus hod_id) on insert so
-- a HOD can create their own point from the app (same as the sites fix).
-- ============================================================================
DROP TRIGGER IF EXISTS trg_thavvu_points_hod_id ON public.thavvu_points;

CREATE OR REPLACE FUNCTION public.trg_thavvu_points_stamp()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.hod_id := COALESCE(NEW.hod_id, public.current_hod_id());
  NEW.created_by := COALESCE(NEW.created_by, auth.uid());
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_thavvu_points_stamp BEFORE INSERT ON public.thavvu_points
  FOR EACH ROW EXECUTE FUNCTION public.trg_thavvu_points_stamp();
