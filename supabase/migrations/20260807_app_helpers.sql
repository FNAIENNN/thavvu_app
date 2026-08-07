-- Thavvu app helper tables (idempotent)
-- Applied to Supabase project qpecrrhindaegcdfcbuz

CREATE TABLE IF NOT EXISTS app_credentials (
  profile_id uuid PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  password_hash text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app_photo_uploads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text,
  thavvu_point_id text,
  module text NOT NULL,
  label text,
  file_name text,
  content_type text DEFAULT 'image/jpeg',
  storage_bucket text,
  storage_path text,
  local_path text,
  uploaded_by uuid,
  hod_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app_activity_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id text,
  thavvu_point_id text,
  actor_id uuid,
  actor_role text,
  module text NOT NULL,
  action text NOT NULL,
  entity_type text,
  entity_id text,
  summary text,
  quantity numeric,
  unit text,
  meta jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  hod_id uuid
);

CREATE INDEX IF NOT EXISTS app_activity_events_created_idx ON app_activity_events(created_at DESC);
CREATE INDEX IF NOT EXISTS app_activity_events_site_idx ON app_activity_events(site_id, created_at DESC);

-- Seed demo credentials for existing profiles (password: password)
INSERT INTO app_credentials(profile_id, password_hash)
SELECT id, 'plain:password' FROM profiles
ON CONFLICT (profile_id) DO NOTHING;

-- Normalize fuel / chemical units
UPDATE stock_items SET category='Diesel', uom='LITRE', primary_uom='LITRE'
WHERE lower(coalesce(code,item_code,name,item_name,'')) LIKE '%diesel%';

UPDATE stock_items SET category='Petrol', uom='LITRE', primary_uom='LITRE'
WHERE lower(coalesce(code,item_code,name,item_name,'')) LIKE '%petrol%';

UPDATE stock_items SET category='Cement', uom='BAG', primary_uom='BAG'
WHERE lower(coalesce(category,name,item_name,'')) LIKE '%cement%';

