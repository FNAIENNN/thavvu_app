-- ============================================================================
-- Migration 00058: Remove the final E2E registration account created during
-- verification of the fixed approve flow (00055). The demo project stays a
-- clean slate: only demo supervisor owns TP-VJA-001, no leftover requests.
--
-- Order matters: thavvu_point_assignments.supervisor_id has NO ON DELETE
-- CASCADE (only point/site FKs cascade), so the assignment row must be
-- removed before the auth user / profile.
-- ============================================================================

DELETE FROM public.thavvu_point_assignments
 WHERE supervisor_id IN (
   SELECT id FROM auth.users WHERE email LIKE 'e2e-final-%@thavvu.com'
 );

DELETE FROM public.supervisor_registration_requests
 WHERE email LIKE 'e2e-final-%@thavvu.com';

DELETE FROM auth.users
 WHERE email LIKE 'e2e-final-%@thavvu.com';
