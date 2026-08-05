-- Thavvu App: Real supervisor account provisioning (migration 00034)
--
-- Fixes the "Create Supervisor Login" workflow. Previously the HOD screen
-- only stored a fake local account (SharedPreferences), so the credentials
-- were rejected by Supabase Auth on the real login screen. This RPC creates
-- a REAL, email-confirmed auth user (+ identity row + profile via the
-- existing on_auth_user_created trigger) and optionally assigns the new
-- supervisor to a site + Thavvu Point so they can start working immediately.
--
-- Caller: authenticated HOD accounts (checked inside the function body).

CREATE OR REPLACE FUNCTION public.admin_create_supervisor(
  p_name text,
  p_email text,
  p_phone text,
  p_password text,
  p_site_id text DEFAULT NULL,
  p_point_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, auth
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_caller_role text;
  v_user_id uuid := gen_random_uuid();
  v_instance uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_email text := lower(trim(p_email));
  v_emp_id text;
BEGIN
  -- 1) Guard: only authenticated HOD accounts may create supervisors.
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  SELECT COALESCE(raw_user_meta_data->>'role', '') INTO v_caller_role
  FROM auth.users WHERE id = v_caller;
  IF v_caller_role <> 'hod' THEN
    RAISE EXCEPTION 'Only HOD accounts can create supervisors';
  END IF;

  -- 2) Input validation (mirrors the app-side checks).
  IF length(trim(p_name)) < 3 THEN
    RAISE EXCEPTION 'Enter a valid supervisor name';
  END IF;
  IF length(v_email) < 6 OR position('@' in v_email) = 0 THEN
    RAISE EXCEPTION 'Enter a valid supervisor email';
  END IF;
  IF length(trim(p_phone)) < 8 THEN
    RAISE EXCEPTION 'Enter a valid supervisor phone number';
  END IF;
  IF length(trim(p_password)) < 6 THEN
    RAISE EXCEPTION 'Password must be at least 6 characters';
  END IF;

  -- 3) Idempotency: one account per email.
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_email) THEN
    RAISE EXCEPTION 'A supervisor already exists with this email';
  END IF;

  -- 4) Human-readable employee id matching the HOD card ids (THV-SUP-001...).
  v_emp_id := 'THV-SUP-' || lpad(
    ((SELECT count(*)::int FROM public.profiles WHERE role = 'supervisor') + 1)::text,
    3, '0');

  -- 5) Create a REAL email-confirmed auth user (pattern from 00009 + 00014:
  --    token columns are non-NULL so GoTrue can scan the row).
  INSERT INTO auth.users
    (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
     raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
     confirmation_token, recovery_token, email_change_token_new, email_change)
  VALUES
    (v_user_id, v_instance, 'authenticated', 'authenticated', v_email,
     extensions.crypt(trim(p_password), extensions.gen_salt('bf')), now(),
     jsonb_build_object('provider', 'email',
                        'providers', jsonb_build_array('email')),
     jsonb_build_object('emp_id', v_emp_id,
                        'full_name', trim(p_name),
                        'role', 'supervisor',
                        'phone', trim(p_phone)),
     now(), now(), '', '', '', '');

  -- 6) Identity row — GoTrue requires it for password login (pattern 00010).
  INSERT INTO auth.identities
    (id, user_id, identity_data, provider, provider_id, last_sign_in_at,
     created_at, updated_at)
  VALUES
    (v_user_id, v_user_id,
     jsonb_build_object('sub', v_user_id::text,
                        'email', v_email,
                        'email_verified', true,
                        'phone_verified', false),
     'email', v_user_id::text, now(), now(), now());

  -- 7) The on_auth_user_created trigger created the profile; set phone.
  UPDATE public.profiles SET phone = trim(p_phone) WHERE id = v_user_id;

  -- 8) Optional site + point assignment so the supervisor can work now.
  IF p_site_id IS NOT NULL AND p_point_id IS NOT NULL THEN
    INSERT INTO public.thavvu_point_assignments
      (id, thavvu_point_id, supervisor_id, site_id, assigned_by, is_active, assigned_at)
    VALUES
      (gen_random_uuid(), p_point_id, v_user_id, p_site_id, v_caller, true, now())
    ON CONFLICT DO NOTHING;
    INSERT INTO public.site_memberships
      (id, site_id, profile_id, role, is_active, assigned_by, assigned_at)
    VALUES
      (gen_random_uuid(), p_site_id, v_user_id, 'supervisor', true, v_caller, now())
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'id', v_user_id::text,
    'emp_id', v_emp_id,
    'email', v_email,
    'status', 'created');
END;
$$;

-- Only authenticated users may invoke it; the HOD check is inside the body.
REVOKE ALL ON FUNCTION public.admin_create_supervisor(text, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_create_supervisor(text, text, text, text, text, text) TO authenticated;
