-- Thavvu App: Workers, Attendance & Food (migration 00005)

-- ============================================================
-- 1. WORKERS (master identity data, created by HOD/admin)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.workers (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id            TEXT REFERENCES public.sites(id) ON DELETE SET NULL,
  thavvu_point_id    TEXT REFERENCES public.thavvu_points(id) ON DELETE SET NULL,
  name               TEXT NOT NULL,
  department         TEXT,
  phone              TEXT,
  aadhar_number      TEXT UNIQUE,
  face_id            TEXT UNIQUE,          -- enrolled face identifier (stored, verifiable)
  biometric_id       TEXT,
  worker_photo_url   TEXT,                 -- Supabase Storage path
  aadhar_photo_url   TEXT,
  bank_book_photo_url TEXT,
  referral_name      TEXT,
  joining_date       DATE,
  wage               NUMERIC(10,2),
  status             TEXT NOT NULL DEFAULT 'active'
                     CHECK (status IN ('active','inactive','leave','closed')),
  is_temporary       BOOLEAN NOT NULL DEFAULT false,
  created_by         UUID REFERENCES public.profiles(id),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_workers_site ON public.workers(site_id);
CREATE INDEX idx_workers_status ON public.workers(status);
CREATE TRIGGER trg_workers_updated_at
  BEFORE UPDATE ON public.workers
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 2. ATTENDANCE RECORDS (one row per worker per day)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.attendance_records (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id             TEXT REFERENCES public.sites(id) ON DELETE SET NULL,
  thavvu_point_id     TEXT REFERENCES public.thavvu_points(id) ON DELETE SET NULL,
  worker_id           UUID NOT NULL REFERENCES public.workers(id) ON DELETE CASCADE,
  attendance_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  status              TEXT NOT NULL DEFAULT 'Present'
                      CHECK (status IN ('Present','Absent','Half day','Leave','Not Marked')),
  check_in_time       TIMESTAMPTZ,
  check_out_time      TIMESTAMPTZ,
  check_in_method     TEXT CHECK (check_in_method IN ('face','biometric','manual','manual_photo')),
  check_out_method    TEXT CHECK (check_out_method IN ('face','biometric','manual','manual_photo')),
  check_in_photo_url  TEXT,
  check_out_photo_url TEXT,
  half_day_photo_url  TEXT,
  afternoon_photo_url TEXT,
  geo_location        TEXT,
  food_opt_in         BOOLEAN NOT NULL DEFAULT true,   -- <-- who needs food (attendance's only food duty)
  hod_approval_status TEXT NOT NULL DEFAULT 'pending'
                      CHECK (hod_approval_status IN ('pending','approved','rejected')),
  hod_remark          TEXT,
  marked_by           UUID REFERENCES public.profiles(id),  -- supervisor who marked it
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (worker_id, attendance_date)
);

CREATE INDEX idx_attendance_date_site ON public.attendance_records(attendance_date, site_id);
CREATE INDEX idx_attendance_worker_date ON public.attendance_records(worker_id, attendance_date);
CREATE TRIGGER trg_attendance_records_updated_at
  BEFORE UPDATE ON public.attendance_records
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 3. OUTSIDE WORKER BATCHES (supplier batch check-in)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.attendance_batches (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id                TEXT REFERENCES public.sites(id) ON DELETE SET NULL,
  thavvu_point_id        TEXT REFERENCES public.thavvu_points(id) ON DELETE SET NULL,
  attendance_date        DATE NOT NULL DEFAULT CURRENT_DATE,
  batch_number           INTEGER NOT NULL,
  supplier               TEXT NOT NULL,
  session_type           TEXT NOT NULL,
  shift_state            TEXT NOT NULL DEFAULT 'active'
                         CHECK (shift_state IN ('active','pendingContinuation','fullDayActive','shiftEnded','pendingEndShift')),
  photo_url              TEXT,
  geo_location           TEXT,
  continuation_photo_url TEXT,
  end_shift_photo_url    TEXT,
  end_shift_geo_location TEXT,
  marked_by              UUID REFERENCES public.profiles(id),
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_batches_date_site ON public.attendance_batches(attendance_date, site_id);
CREATE TRIGGER trg_attendance_batches_updated_at
  BEFORE UPDATE ON public.attendance_batches
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- Individual outside workers inside a batch
CREATE TABLE IF NOT EXISTS public.attendance_batch_workers (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id          UUID NOT NULL REFERENCES public.attendance_batches(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  wage              NUMERIC(10,2),
  attendance_status TEXT NOT NULL DEFAULT 'Present'
                    CHECK (attendance_status IN ('Present','Absent','Half day','Leave')),
  food_opt_in       BOOLEAN NOT NULL DEFAULT true,   -- <-- who needs food
  supplier          TEXT
);

CREATE INDEX idx_batch_workers_batch ON public.attendance_batch_workers(batch_id);

-- ============================================================
-- 4. FOOD REQUESTS (derived from attendance opt-ins; food module consumes)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.food_requests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id           TEXT REFERENCES public.sites(id) ON DELETE SET NULL,
  thavvu_point_id   TEXT REFERENCES public.thavvu_points(id) ON DELETE SET NULL,
  attendance_date   DATE NOT NULL DEFAULT CURRENT_DATE,
  category          TEXT NOT NULL CHECK (category IN ('regular','outside','machine','guest','other')),
  worker_id         UUID REFERENCES public.workers(id) ON DELETE CASCADE,           -- null for non-regular
  batch_worker_id   UUID REFERENCES public.attendance_batch_workers(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,           -- denormalized snapshot for display
  status            TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','submitted','cancelled')),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (worker_id, batch_worker_id, attendance_date, category)
);

CREATE INDEX idx_food_requests_date_site ON public.food_requests(attendance_date, site_id);

-- ============================================================
-- 5. FOOD SUBMISSIONS (supervisor → HOD daily food count)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.food_submissions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id               TEXT REFERENCES public.sites(id) ON DELETE SET NULL,
  thavvu_point_id       TEXT REFERENCES public.thavvu_points(id) ON DELETE SET NULL,
  attendance_date       DATE NOT NULL DEFAULT CURRENT_DATE,
  shifts                TEXT[] NOT NULL DEFAULT '{}',
  regular_worker_count  INTEGER NOT NULL DEFAULT 0,
  outside_worker_count  INTEGER NOT NULL DEFAULT 0,
  machine_worker_count  INTEGER NOT NULL DEFAULT 0,
  guest_count           INTEGER NOT NULL DEFAULT 0,
  other_count           INTEGER NOT NULL DEFAULT 0,
  remarks               TEXT,
  payload               JSONB,               -- full snapshot for audit
  status                TEXT NOT NULL DEFAULT 'submitted'
                        CHECK (status IN ('submitted','approved','rejected')),
  submitted_by          UUID REFERENCES public.profiles(id),
  submitted_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (site_id, attendance_date, submitted_by)
);

CREATE INDEX idx_food_submissions_date_site ON public.food_submissions(attendance_date, site_id);

-- ============================================================
-- 6. STORAGE BUCKET — attendance selfie/proof photos
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'attendance-photos',
  'attendance-photos',
  false,
  10485760, -- 10 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
) ON CONFLICT (id) DO NOTHING;

CREATE POLICY "attendance_photos_select_authenticated"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'attendance-photos' AND auth.role() = 'authenticated');

CREATE POLICY "attendance_photos_insert_own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'attendance-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "attendance_photos_delete_own"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'attendance-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ============================================================
-- 7. RLS — workers / attendance / food
-- ============================================================
ALTER TABLE public.workers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "workers_select_site_members" ON public.workers FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships
            WHERE site_id = workers.site_id AND profile_id = auth.uid() AND is_active = true)
    OR public.has_role(ARRAY['hod','admin'])
  );
CREATE POLICY "workers_insert_hod_admin" ON public.workers FOR INSERT
  WITH CHECK (public.has_role(ARRAY['hod','admin']));
CREATE POLICY "workers_update_hod_admin" ON public.workers FOR UPDATE
  USING (public.has_role(ARRAY['hod','admin']));

ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "attendance_records_select_site_members" ON public.attendance_records FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships
            WHERE site_id = attendance_records.site_id AND profile_id = auth.uid() AND is_active = true)
    OR public.has_role(ARRAY['hod','admin','finance'])
  );
CREATE POLICY "attendance_records_insert_supervisor" ON public.attendance_records FOR INSERT
  WITH CHECK (public.has_role(ARRAY['hod','supervisor','admin']));
CREATE POLICY "attendance_records_update_supervisor" ON public.attendance_records FOR UPDATE
  USING (public.has_role(ARRAY['hod','supervisor','admin']));

ALTER TABLE public.attendance_batches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "batches_select_site_members" ON public.attendance_batches FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships
            WHERE site_id = attendance_batches.site_id AND profile_id = auth.uid() AND is_active = true)
    OR public.has_role(ARRAY['hod','admin','finance'])
  );
CREATE POLICY "batches_insert_supervisor" ON public.attendance_batches FOR INSERT
  WITH CHECK (public.has_role(ARRAY['hod','supervisor','admin']));
CREATE POLICY "batches_update_supervisor" ON public.attendance_batches FOR UPDATE
  USING (public.has_role(ARRAY['hod','supervisor','admin']));

ALTER TABLE public.attendance_batch_workers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "batch_workers_select_via_batch" ON public.attendance_batch_workers FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.attendance_batches b
            JOIN public.site_memberships sm ON sm.site_id = b.site_id
            WHERE b.id = attendance_batch_workers.batch_id AND sm.profile_id = auth.uid() AND sm.is_active = true)
    OR public.has_role(ARRAY['hod','admin','finance'])
  );
CREATE POLICY "batch_workers_insert_via_batch" ON public.attendance_batch_workers FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.attendance_batches b
            WHERE b.id = attendance_batch_workers.batch_id AND public.has_role(ARRAY['hod','supervisor','admin']))
  );

ALTER TABLE public.food_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "food_requests_select_site_members" ON public.food_requests FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships
            WHERE site_id = food_requests.site_id AND profile_id = auth.uid() AND is_active = true)
    OR public.has_role(ARRAY['hod','admin','finance'])
  );
CREATE POLICY "food_requests_insert_supervisor" ON public.food_requests FOR INSERT
  WITH CHECK (public.has_role(ARRAY['hod','supervisor','admin']));
CREATE POLICY "food_requests_delete_supervisor" ON public.food_requests FOR DELETE
  USING (public.has_role(ARRAY['hod','supervisor','admin']));

ALTER TABLE public.food_submissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "food_submissions_select_site_members" ON public.food_submissions FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.site_memberships
            WHERE site_id = food_submissions.site_id AND profile_id = auth.uid() AND is_active = true)
    OR public.has_role(ARRAY['hod','admin','finance'])
  );
CREATE POLICY "food_submissions_insert_supervisor" ON public.food_submissions FOR INSERT
  WITH CHECK (public.has_role(ARRAY['hod','supervisor','admin']));
CREATE POLICY "food_submissions_update_hod" ON public.food_submissions FOR UPDATE
  USING (public.has_role(ARRAY['hod','admin']));
