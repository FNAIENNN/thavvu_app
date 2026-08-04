-- Thavvu App: Allow site-member supervisors to register workers (migration 00016)
--
-- Supervisors register temporary workers on-site from the attendance
-- screen and enroll face signatures. The previous policies restricted
-- workers INSERT/UPDATE to HOD/admin only, which blocked supervisors
-- (RLS 42501). Members of a site can now insert/update workers for
-- that site; HOD/admin keep global access.
DROP POLICY IF EXISTS "workers_insert_hod_admin" ON public.workers;
CREATE POLICY "workers_insert_members" ON public.workers FOR INSERT
  WITH CHECK (
    public.has_role(ARRAY['hod', 'admin'])
    OR (
      public.has_role(ARRAY['supervisor'])
      AND EXISTS (
        SELECT 1 FROM public.site_memberships
        WHERE site_id = workers.site_id
          AND profile_id = auth.uid()
          AND is_active = true
      )
    )
  );

DROP POLICY IF EXISTS "workers_update_hod_admin" ON public.workers;
CREATE POLICY "workers_update_members" ON public.workers FOR UPDATE
  USING (
    public.has_role(ARRAY['hod', 'admin'])
    OR (
      public.has_role(ARRAY['supervisor'])
      AND EXISTS (
        SELECT 1 FROM public.site_memberships
        WHERE site_id = workers.site_id
          AND profile_id = auth.uid()
          AND is_active = true
      )
    )
  );
