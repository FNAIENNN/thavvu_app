-- Thavvu App: Restore standard auth-schema grants (migration 00011)
--
-- GoTrue connects to the database as `supabase_auth_admin`. This project
-- was missing the standard grants on the auth schema, so every login
-- failed with "Database error querying schema". Restores the grants that
-- a healthy Supabase project ships with.
GRANT USAGE ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA auth TO supabase_auth_admin;

-- The anon/authenticated roles read auth.uid()/auth.role() which live in
-- the auth schema; ensure those helpers stay callable.
GRANT USAGE ON SCHEMA auth TO anon, authenticated;
