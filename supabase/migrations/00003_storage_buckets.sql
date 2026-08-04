-- Thavvu App: Supabase Storage Buckets
-- Private buckets for machine-related files

-- ============================================================
-- 16. STORAGE BUCKETS
-- ============================================================

-- Machine opening photos (supervisor captures when starting work)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'machine-opening-photos',
  'machine-opening-photos',
  false,
  10485760, -- 10 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
) ON CONFLICT (id) DO NOTHING;

-- Payment proofs (HOD/finance uploads)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'machine-payment-proofs',
  'machine-payment-proofs',
  false,
  20971520, -- 20 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::text[]
) ON CONFLICT (id) DO NOTHING;

-- Daily attachments (bills, screenshots, etc.)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'machine-daily-attachments',
  'machine-daily-attachments',
  false,
  20971520, -- 20 MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']::text[]
) ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- STORAGE RLS
-- ============================================================

-- Opening photos: supervisors can CRUD own; HOD can read
CREATE POLICY "opening_photos_select_own"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'machine-opening-photos'
    AND (
      auth.role() = 'authenticated'
    )
  );

CREATE POLICY "opening_photos_insert_own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'machine-opening-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "opening_photos_delete_own"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'machine-opening-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Payment proofs: HOD and finance can read/insert
CREATE POLICY "payment_proofs_select"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'machine-payment-proofs'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "payment_proofs_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'machine-payment-proofs'
    AND (
      public.has_role(ARRAY['hod', 'finance', 'admin'])
      OR (storage.foldername(name))[1] = auth.uid()::text
    )
  );

-- Daily attachments: supervisors upload own; HOD can read
CREATE POLICY "daily_attachments_select"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'machine-daily-attachments'
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "daily_attachments_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'machine-daily-attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
