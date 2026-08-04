-- Thavvu App: HOD approval columns for outside-worker batches (migration 00007)
ALTER TABLE public.attendance_batches
  ADD COLUMN IF NOT EXISTS hod_approval_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (hod_approval_status IN ('pending','approved','rejected')),
  ADD COLUMN IF NOT EXISTS hod_remark TEXT;
