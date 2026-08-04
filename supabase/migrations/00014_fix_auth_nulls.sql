-- Thavvu App: Fix NULL token columns in auth.users (migration 00014)
--
-- GoTrue fails with "Database error querying schema" when string columns
-- in auth.users are NULL (it scans them as plain strings). Users seeded
-- directly in migration 00009 left several columns NULL. This applies the
-- fix documented by Supabase: convert NULLs to empty strings / false.
UPDATE auth.users
SET confirmation_token     = COALESCE(confirmation_token, ''),
    recovery_token         = COALESCE(recovery_token, ''),
    email_change_token_new = COALESCE(email_change_token_new, ''),
    email_change           = COALESCE(email_change, ''),
    is_super_admin         = COALESCE(is_super_admin, false)
WHERE email IN ('hod@thavvu.com', 'supervisor@thavvu.com');
