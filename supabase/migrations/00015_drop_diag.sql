-- Thavvu App: Drop temporary diagnostics (migration 00015)
-- Removes the dev-only _diag table used to debug the auth schema issue.
DROP TABLE IF EXISTS public._diag;
