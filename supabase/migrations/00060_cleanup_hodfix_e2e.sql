-- ============================================================================
-- Migration 00060: Remove the E2E account created to verify the hardened
-- admin_create_supervisor guard (00059). Clean slate: demo supervisor keeps
-- TP-VJA-001, TP-VJA-002 returns to unassigned.
-- ============================================================================

DELETE FROM public.thavvu_point_assignments
 WHERE supervisor_id IN (
   SELECT id FROM auth.users WHERE email LIKE 'e2e-hodfix-%@thavvu.com'
 );

DELETE FROM auth.users
 WHERE email LIKE 'e2e-hodfix-%@thavvu.com';
