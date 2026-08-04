-- Thavvu App: Development Seed Data
-- Inserts demo users, sites, Thavvu Points, and machine suppliers
-- Run ONLY in development/staging environments.

-- ============================================================
-- DO NOT RUN IN PRODUCTION
-- ============================================================
-- This seed references fixed UUIDs for local development.
-- In production, use auth.admin.create_user() or invite flows.

-- ============================================================
-- SEED PROFILES (matching existing app hardcoded IDs)
-- ============================================================
-- NOTE: Real auth.users must exist first. This seed assumes
-- the following users have been created separately:
--   HOD:         hod@thavvu.com / hod1234
--   Supervisor:  supervisor@thavvu.com / super123
--   Supervisor2: mohan@thavvu.com / mohan123
-- For true local dev without auth, use the SQL below with
-- manually inserted auth.users or skip auth checks.

-- To actually seed profiles after auth.users exist:
-- INSERT INTO public.profiles (id, emp_id, full_name, email, role, is_active)
-- VALUES
--   ('00000000-0000-0000-0000-000000000001', 'HOD-001', 'HOD Admin', 'hod@thavvu.com', 'hod', true),
--   ('00000000-0000-0000-0000-000000000002', 'THV-SUP-001', 'Supervisor Rajesh', 'supervisor@thavvu.com', 'supervisor', true),
--   ('00000000-0000-0000-0000-000000000003', 'THV-SUP-002', 'Supervisor Mohan', 'mohan@thavvu.com', 'supervisor', true);

-- ============================================================
-- SEED SITES
-- ============================================================
-- INSERT INTO public.sites (id, name, place, admin_name, acres, status, created_by)
-- VALUES
--   ('SITE-VJA-001', 'Vijayawada River Bed', 'Vijayawada', 'Admin Prakash', 48, 'active', '00000000-0000-0000-0000-000000000001'),
--   ('SITE-AKV-002', 'Akividu Canal Line', 'Akividu', 'Admin Kavitha', 26, 'active', '00000000-0000-0000-0000-000000000001'),
--   ('SITE-RJM-003', 'Rajahmundry Lift Point', 'Rajahmundry', 'Admin Suresh', 34, 'active', '00000000-0000-0000-0000-000000000001')
-- ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- SEED THAVVU POINTS
-- ============================================================
-- INSERT INTO public.thavvu_points (id, site_id, point_name, assigned_acres, status, created_by, granted_at, granted_by)
-- VALUES
--   ('TP-VJA-001', 'SITE-VJA-001', 'East Ramp Loading Point', 18, 'granted', '00000000-0000-0000-0000-000000000001', now(), '00000000-0000-0000-0000-000000000001'),
--   ('TP-VJA-002', 'SITE-VJA-001', 'River Sand Screening Point', 12, 'granted', '00000000-0000-0000-0000-000000000001', now(), '00000000-0000-0000-0000-000000000001'),
--   ('TP-AKV-001', 'SITE-AKV-002', 'Canal Bund Earthwork Point', 10, 'granted', '00000000-0000-0000-0000-000000000001', now(), '00000000-0000-0000-0000-000000000001')
-- ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- SEED THAVVU POINT ASSIGNMENTS
-- ============================================================
-- INSERT INTO public.thavvu_point_assignments (thavvu_point_id, supervisor_id, site_id, assigned_by, is_active, assigned_at)
-- VALUES
--   ('TP-VJA-001', '00000000-0000-0000-0000-000000000002', 'SITE-VJA-001', '00000000-0000-0000-0000-000000000001', true, now()),
--   ('TP-VJA-002', '00000000-0000-0000-0000-000000000002', 'SITE-VJA-001', '00000000-0000-0000-0000-000000000001', true, now()),
--   ('TP-AKV-001', '00000000-0000-0000-0000-000000000003', 'SITE-AKV-002', '00000000-0000-0000-0000-000000000001', true, now());

-- ============================================================
-- SEED SITE MEMBERSHIPS
-- ============================================================
-- INSERT INTO public.site_memberships (site_id, profile_id, role, assigned_by)
-- VALUES
--   ('SITE-VJA-001', '00000000-0000-0000-0000-000000000001', 'hod', '00000000-0000-0000-0000-000000000001'),
--   ('SITE-AKV-002', '00000000-0000-0000-0000-000000000001', 'hod', '00000000-0000-0000-0000-000000000001'),
--   ('SITE-RJM-003', '00000000-0000-0000-0000-000000000001', 'hod', '00000000-0000-0000-0000-000000000001'),
--   ('SITE-VJA-001', '00000000-0000-0000-0000-000000000002', 'supervisor', '00000000-0000-0000-0000-000000000001'),
--   ('SITE-AKV-002', '00000000-0000-0000-0000-000000000003', 'supervisor', '00000000-0000-0000-0000-000000000001');

-- ============================================================
-- SEED MACHINE SUPPLIERS
-- ============================================================
-- INSERT INTO public.machine_suppliers (id, site_id, name, type, phone, rating, notes, created_by)
-- VALUES
--   ('SUPPLIER-001', 'SITE-VJA-001', 'ABC Earth Movers', 'permanent', '9876500011', 4.6, 'Preferred permanent supplier', '00000000-0000-0000-0000-000000000001'),
--   ('SUPPLIER-002', 'SITE-VJA-001', 'Delta Machinery Rentals', 'temporary', '9876500022', 4.1, 'Temporary backup supplier', '00000000-0000-0000-0000-000000000001')
-- ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- SEED MACHINE ASSETS
-- ============================================================
-- INSERT INTO public.machine_assets (id, site_id, machine_name, vehicle_number, vehicle_type, operator_name, operator_phone, created_by)
-- VALUES
--   ('MACHINE-001', 'SITE-VJA-001', 'JCB Backhoe 3DX', 'AP16JC9090', 'Backhoe', 'Mahesh', '9876500999', '00000000-0000-0000-0000-000000000001')
-- ON CONFLICT (id) DO NOTHING;
