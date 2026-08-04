-- Thavvu App: Temporary diagnostics table (migration 00012)
-- Dev-only: records GoTrue schema-check findings for debugging the
-- "Database error querying schema" login failure. Readable via anon REST
-- so it can be inspected without direct DB access. Safe to drop after use.
CREATE TABLE IF NOT EXISTS public._diag (
  k TEXT PRIMARY KEY,
  v TEXT
);

-- Expected auth tables (GoTrue CheckDatabaseSchema list)
INSERT INTO public._diag (k, v)
SELECT 'table:' || t.tablename, 'exists'
FROM pg_tables t
WHERE t.schemaname = 'auth'
  AND t.tablename IN ('users','identities','sessions','refresh_tokens',
      'one_time_tokens','mfa_factors','mfa_challenges','audit_log_entries',
      'flow_state','saml_providers','saml_relay_states','sso_providers',
      'sso_domains','webauthn_challenges','webauthn_credentials')
ON CONFLICT (k) DO UPDATE SET v = EXCLUDED.v;

-- Expected auth.users columns (newer GoTrue checks)
INSERT INTO public._diag (k, v)
SELECT 'users_col:' || c.column_name, 'exists'
FROM information_schema.columns c
WHERE c.table_schema = 'auth' AND c.table_name = 'users'
  AND c.column_name IN ('email_change_token_current','email_change_confirm_status',
      'banned_until','reauthentication_token','reauthentication_sent_at',
      'is_sso_user','deleted_at','is_anonymous','confirmation_token','recovery_token')
ON CONFLICT (k) DO UPDATE SET v = EXCLUDED.v;

-- ACL on auth.users for GoTrue's role
INSERT INTO public._diag (k, v)
SELECT 'acl:auth.users', c.relacl::text
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'auth' AND c.relname = 'users'
ON CONFLICT (k) DO UPDATE SET v = EXCLUDED.v;

-- Total expected table count signal
INSERT INTO public._diag (k, v)
SELECT 'auth_table_count',
       (SELECT count(*)::text FROM pg_tables WHERE schemaname = 'auth')
ON CONFLICT (k) DO UPDATE SET v = EXCLUDED.v;

-- Make the diag table readable by anon (dev-only)
ALTER TABLE public._diag ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "diag_select_anon" ON public._diag;
CREATE POLICY "diag_select_anon" ON public._diag FOR SELECT USING (true);
