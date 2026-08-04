-- Thavvu App: Attendance Dev Seed Data (migration 00006)
-- Inserts a small set of workers with enrolled face IDs for the
-- demo site SITE-VJA-001 so attendance can be exercised end-to-end.
--
-- Safe by design: each INSERT is guarded by an EXISTS check on the
-- referenced site / profile and uses ON CONFLICT DO NOTHING, so this
-- migration is a no-op in environments where the demo site does not exist.

-- ============================================================
-- SEED WORKERS (regular workers with enrolled face IDs)
-- ============================================================
INSERT INTO public.workers
  (site_id, thavvu_point_id, name, department, phone, aadhar_number,
   face_id, biometric_id, status, is_temporary, joining_date, wage, created_by)
SELECT 'SITE-VJA-001', 'TP-VJA-001', 'Ravi Kumar',  'Loading Crew',  '9876543201', '9000000001',
       'FACE-ravi', 'BIO-ravi', 'active', false, CURRENT_DATE - 120, 550,
       '00000000-0000-0000-0000-000000000001'
WHERE EXISTS (SELECT 1 FROM public.sites WHERE id = 'SITE-VJA-001')
ON CONFLICT (face_id) DO NOTHING;

INSERT INTO public.workers
  (site_id, thavvu_point_id, name, department, phone, aadhar_number,
   face_id, biometric_id, status, is_temporary, joining_date, wage, created_by)
SELECT 'SITE-VJA-001', 'TP-VJA-001', 'Suresh Babu', 'Screening',    '9876543202', '9000000002',
       'FACE-suresh', 'BIO-suresh', 'active', false, CURRENT_DATE - 200, 500,
       '00000000-0000-0000-0000-000000000001'
WHERE EXISTS (SELECT 1 FROM public.sites WHERE id = 'SITE-VJA-001')
ON CONFLICT (face_id) DO NOTHING;

INSERT INTO public.workers
  (site_id, thavvu_point_id, name, department, phone, aadhar_number,
   face_id, biometric_id, status, is_temporary, joining_date, wage, created_by)
SELECT 'SITE-VJA-001', 'TP-VJA-002', 'Mariyamma',   'Canal Work',   '9876543203', '9000000003',
       'FACE-mariyamma', 'BIO-mariyamma', 'active', false, CURRENT_DATE - 90, 450,
       '00000000-0000-0000-0000-000000000001'
WHERE EXISTS (SELECT 1 FROM public.sites WHERE id = 'SITE-VJA-001')
ON CONFLICT (face_id) DO NOTHING;

INSERT INTO public.workers
  (site_id, thavvu_point_id, name, department, phone, aadhar_number,
   face_id, biometric_id, status, is_temporary, joining_date, wage, created_by)
SELECT 'SITE-VJA-001', 'TP-VJA-002', 'Lakshman',    'Machine Help', '9876543204', '9000000004',
       'FACE-lakshman', 'BIO-lakshman', 'active', false, CURRENT_DATE - 60, 520,
       '00000000-0000-0000-0000-000000000001'
WHERE EXISTS (SELECT 1 FROM public.sites WHERE id = 'SITE-VJA-001')
ON CONFLICT (face_id) DO NOTHING;

INSERT INTO public.workers
  (site_id, thavvu_point_id, name, department, phone, aadhar_number,
   face_id, biometric_id, status, is_temporary, joining_date, wage, created_by)
SELECT 'SITE-VJA-001', 'TP-VJA-001', 'Venkatesh',   'Temporary',    '9876543205', NULL,
       'FACE-venkatesh', NULL, 'active', true, CURRENT_DATE - 5, 480,
       '00000000-0000-0000-0000-000000000001'
WHERE EXISTS (SELECT 1 FROM public.sites WHERE id = 'SITE-VJA-001')
ON CONFLICT (face_id) DO NOTHING;
