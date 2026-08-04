-- Thavvu App: Auth identities for seeded demo users (migration 00010)
--
-- GoTrue requires an `email` identity row per user. Users seeded directly
-- into auth.users (migration 00009) bypassed identity creation, which
-- breaks password login. This backfills the missing identities.
INSERT INTO auth.identities
  (id, user_id, identity_data, provider, provider_id, last_sign_in_at,
   created_at, updated_at)
VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","email":"hod@thavvu.com","email_verified":true,"phone_verified":false}',
   'email', 'aaaaaaaa-0000-0000-0000-000000000001', now(), now(), now()),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000002',
   '{"sub":"aaaaaaaa-0000-0000-0000-000000000002","email":"supervisor@thavvu.com","email_verified":true,"phone_verified":false}',
   'email', 'aaaaaaaa-0000-0000-0000-000000000002', now(), now(), now())
ON CONFLICT (id) DO NOTHING;
