-- ============================================================================
-- Migration 00025: Legacy Machines screen server sync.
--
-- The legacy Machines screen (machines_entry_screen_.dart) submits entries
-- with catalog ids MCH-001..003. machine_daily_logs.machine_id is a NOT NULL
-- FK to machine_assets, so those assets must exist before the app can sync.
-- Also, machine_daily_diesel_lines has RLS enabled with no policies, which
-- locks the table for everyone — add read/insert policies mirroring the
-- daily logs rules.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Seed the legacy catalog machines (idempotent; no-op if profiles are empty)
-- ---------------------------------------------------------------------------
INSERT INTO public.machine_assets
  (id, site_id, machine_name, vehicle_number, vehicle_type, operator_name, created_by)
SELECT m.id, m.site_id, m.machine_name, m.vehicle_number, m.vehicle_type,
       m.operator_name, COALESCE(p.id, fp.id)
FROM (VALUES
  ('MCH-001', 'SITE-VJA-001', 'Poclain EX-200', 'AP39TB1234', 'Poclain', 'Ravi Kumar'),
  ('MCH-002', 'SITE-VJA-001', 'Farm Tractor 45HP', 'AP37TR4589', 'Tractor', 'Suresh'),
  ('MCH-003', 'SITE-VJA-001', 'JCB Backhoe', 'AP16JC9090', 'Backhoe', 'Mahesh')
) AS m(id, site_id, machine_name, vehicle_number, vehicle_type, operator_name)
LEFT JOIN public.profiles p ON p.email = 'hod@thavvu.com'
CROSS JOIN LATERAL (
  SELECT id FROM public.profiles ORDER BY id LIMIT 1
) fp
WHERE COALESCE(p.id, fp.id) IS NOT NULL
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. RLS for machine_daily_diesel_lines (was enabled with no policies => locked)
-- ---------------------------------------------------------------------------
ALTER TABLE public.machine_daily_diesel_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "diesel_lines_select_related" ON public.machine_daily_diesel_lines;
CREATE POLICY "diesel_lines_select_related"
  ON public.machine_daily_diesel_lines FOR SELECT
  USING (
    daily_log_id IN (
      SELECT id FROM public.machine_daily_logs
      WHERE supervisor_id = auth.uid()
         OR site_id IN (
              SELECT site_id FROM public.site_memberships
              WHERE profile_id = auth.uid() AND is_active = true
                AND role IN ('hod', 'finance', 'admin')
            )
    )
  );

DROP POLICY IF EXISTS "diesel_lines_insert_related" ON public.machine_daily_diesel_lines;
CREATE POLICY "diesel_lines_insert_related"
  ON public.machine_daily_diesel_lines FOR INSERT
  WITH CHECK (
    daily_log_id IN (
      SELECT id FROM public.machine_daily_logs
      WHERE supervisor_id = auth.uid()
         OR public.has_role(ARRAY['hod', 'admin'])
    )
  );
