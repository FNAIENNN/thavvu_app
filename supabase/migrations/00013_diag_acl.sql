-- Thavvu App: Extended ACL diagnostics (migration 00013)
-- Dumps ACLs for every auth table so we can see which tables
-- supabase_auth_admin can actually see in information_schema.
INSERT INTO public._diag (k, v)
SELECT 'acl_table:' || c.relname, c.relacl::text
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'auth' AND c.relkind = 'r'
ON CONFLICT (k) DO UPDATE SET v = EXCLUDED.v;

-- Visibility simulation: count auth tables visible to supabase_auth_admin
-- via information_schema (what GoTrue's schema check sees).
INSERT INTO public._diag (k, v)
SELECT 'visible_to_auth_admin',
  (SELECT count(*)::text FROM information_schema.tables t
   WHERE t.table_schema = 'auth' AND t.table_name IN
     ('users','identities','sessions','refresh_tokens','one_time_tokens',
      'mfa_factors','mfa_challenges','audit_log_entries','flow_state',
      'saml_providers','saml_relay_states','sso_providers','sso_domains',
      'webauthn_challenges','webauthn_credentials','oauth_clients',
      'oauth_authorizations','oauth_consents','oauth_client_states',
      'custom_oauth_providers','instances','audit_log_entries'))
ON CONFLICT (k) DO UPDATE SET v = EXCLUDED.v;
