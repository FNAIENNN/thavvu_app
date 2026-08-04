-- Thavvu App: Demo data seed (migration 00009)
--
-- Creates real auth users + profiles, one site with thavvu points, a
-- supervisor assignment, and a worker set with enrolled face IDs.
-- Idempotent: every insert uses ON CONFLICT DO NOTHING with fixed UUIDs.
--
-- DEMO LOGINS (created below):
--   HOD:         hod@thavvu.com        / Hod@1234
--   Supervisor:  supervisor@thavvu.com / Super@1234
-- (Profiles are auto-created by the handle_new_user trigger.)

-- ============================================================
-- 1. AUTH USERS (fixed UUIDs → predictable profile ids)
-- ============================================================
INSERT INTO auth.users
  (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
   raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'hod@thavvu.com',
   '$2b$10$flSrQ5m1oJ0t762kbDG1pu73gSz6tMvNmnbVJuqqrQy0BlS6LXVs6', now(),
   '{"provider":"email","providers":["email"]}',
   '{"emp_id":"HOD-001","full_name":"HOD Admin","role":"hod"}',
   now(), now()),
  ('aaaaaaaa-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'supervisor@thavvu.com',
   '$2b$10$g/.142Vj.RrYfL5YoBph9eCwZc6SR5u8xzS4gnKqGIIWds9Hr0U8i', now(),
   '{"provider":"email","providers":["email"]}',
   '{"emp_id":"THV-SUP-001","full_name":"Supervisor Rajesh","role":"supervisor"}',
   now(), now())
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 2. SITES
-- ============================================================
INSERT INTO public.sites
  (id, name, place, admin_name, acres, status, created_by)
VALUES
  ('SITE-VJA-001', 'Vijayawada River Bed', 'Vijayawada', 'Admin Prakash', 48,
   'active', 'aaaaaaaa-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 3. THAVVU POINTS
-- ============================================================
INSERT INTO public.thavvu_points
  (id, site_id, point_name, assigned_acres, status, created_by, granted_at, granted_by)
VALUES
  ('TP-VJA-001', 'SITE-VJA-001', 'East Ramp Loading Point', 18, 'granted',
   'aaaaaaaa-0000-0000-0000-000000000001', now(), 'aaaaaaaa-0000-0000-0000-000000000001'),
  ('TP-VJA-002', 'SITE-VJA-001', 'River Sand Screening Point', 12, 'granted',
   'aaaaaaaa-0000-0000-0000-000000000001', now(), 'aaaaaaaa-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 4. THAVVU POINT ASSIGNMENTS (supervisor works SITE-VJA-001)
-- ============================================================
INSERT INTO public.thavvu_point_assignments
  (id, thavvu_point_id, supervisor_id, site_id, assigned_by, is_active, assigned_at)
VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', 'TP-VJA-001',
   'aaaaaaaa-0000-0000-0000-000000000002', 'SITE-VJA-001',
   'aaaaaaaa-0000-0000-0000-000000000001', true, now()),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'TP-VJA-002',
   'aaaaaaaa-0000-0000-0000-000000000002', 'SITE-VJA-001',
   'aaaaaaaa-0000-0000-0000-000000000001', true, now())
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 5. SITE MEMBERSHIPS
-- ============================================================
INSERT INTO public.site_memberships
  (id, site_id, profile_id, role, is_active, assigned_by, assigned_at)
VALUES
  ('cccccccc-0000-0000-0000-000000000001', 'SITE-VJA-001',
   'aaaaaaaa-0000-0000-0000-000000000001', 'hod', true,
   'aaaaaaaa-0000-0000-0000-000000000001', now()),
  ('cccccccc-0000-0000-0000-000000000002', 'SITE-VJA-001',
   'aaaaaaaa-0000-0000-0000-000000000002', 'supervisor', true,
   'aaaaaaaa-0000-0000-0000-000000000001', now())
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 6. WORKERS (enrolled face IDs; signatures added via app enrollment)
-- ============================================================
INSERT INTO public.workers
  (id, site_id, thavvu_point_id, name, department, phone, aadhar_number,
   face_id, biometric_id, status, is_temporary, joining_date, wage, created_by)
VALUES
  ('dddddddd-0000-0000-0000-000000000001', 'SITE-VJA-001', 'TP-VJA-001',
   'Ravi Kumar', 'Loading Crew', '9876543201', '9000000001',
   'FACE-ravi', 'BIO-ravi', 'active', false, CURRENT_DATE - 120, 550,
   'aaaaaaaa-0000-0000-0000-000000000001'),
  ('dddddddd-0000-0000-0000-000000000002', 'SITE-VJA-001', 'TP-VJA-001',
   'Suresh Babu', 'Screening', '9876543202', '9000000002',
   'FACE-suresh', 'BIO-suresh', 'active', false, CURRENT_DATE - 200, 500,
   'aaaaaaaa-0000-0000-0000-000000000001'),
  ('dddddddd-0000-0000-0000-000000000003', 'SITE-VJA-001', 'TP-VJA-002',
   'Mariyamma', 'Canal Work', '9876543203', '9000000003',
   'FACE-mariyamma', 'BIO-mariyamma', 'active', false, CURRENT_DATE - 90, 450,
   'aaaaaaaa-0000-0000-0000-000000000001'),
  ('dddddddd-0000-0000-0000-000000000004', 'SITE-VJA-001', 'TP-VJA-002',
   'Lakshman', 'Machine Help', '9876543204', '9000000004',
   'FACE-lakshman', 'BIO-lakshman', 'active', false, CURRENT_DATE - 60, 520,
   'aaaaaaaa-0000-0000-0000-000000000001'),
  ('dddddddd-0000-0000-0000-000000000005', 'SITE-VJA-001', 'TP-VJA-001',
   'Venkatesh', 'Temporary', '9876543205', NULL,
   'FACE-venkatesh', NULL, 'active', true, CURRENT_DATE - 5, 480,
   'aaaaaaaa-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;
