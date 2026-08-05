-- ============================================================================
-- Migration 00057: Cleanup — drop the approval diagnostic function and remove
-- all automated E2E registration artifacts (requests, auth users, profiles,
-- memberships, point assignments — cascades from auth.users).
-- ============================================================================

DROP FUNCTION IF EXISTS public.diag_approve_point(text, uuid);
DROP FUNCTION IF EXISTS public.diag_approve_point(text);

DELETE FROM public.supervisor_registration_requests
 WHERE email LIKE 'e2e-reg-%@thavvu.com'
    OR email LIKE 'e2e-rej-%@thavvu.com'
    OR email LIKE 'e2e-diag-%@thavvu.com';

-- Cascades: profiles, site_memberships, thavvu_point_assignments,
-- auth.identities.
DELETE FROM auth.users
 WHERE email LIKE 'e2e-reg-%@thavvu.com'
    OR email LIKE 'e2e-rej-%@thavvu.com'
    OR email LIKE 'e2e-diag-%@thavvu.com';
