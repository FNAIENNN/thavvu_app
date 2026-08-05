-- ============================================================================
-- 00063_thavvu_tenant_accounts.sql
-- Enterprise account management under the HOD-as-tenant model.
--   * hod_signup                     — open HOD self-registration (own password)
--   * admin_create_supervisor        — REWRITTEN: tenant-scoped creation
--   * admin_update_supervisor        — HOD edits name/phone of own-department sup
--   * admin_reset_supervisor_password— HOD resets password of own-department sup
--   * admin_deactivate_supervisor    — HOD blocks login of own-department sup
--   * admin_reactivate_supervisor    — HOD re-enables login
--   * approve_supervisor_registration— REWRITTEN: HOD ASSIGNS the password
--   * submit_supervisor_registration — REWRITTEN: request no longer carries a
--                                      password (HOD chooses it at approval)
-- ============================================================================

-- Shared tenant guard: returns the caller's tenant id after verifying the
-- caller is a HOD/admin and that the supervisor belongs to their department.
CREATE OR REPLACE FUNCTION public.assert_my_supervisor(p_supervisor_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_hod    uuid := auth.uid();
  v_sup_hod uuid;
BEGIN
  IF v_hod IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF NOT public.has_role(ARRAY['hod', 'admin']) THEN
    RAISE EXCEPTION 'Only HOD accounts can manage supervisors';
  END IF;
  SELECT hod_id INTO v_sup_hod FROM public.profiles WHERE id = p_supervisor_id;
  IF v_sup_hod IS DISTINCT FROM v_hod THEN
    RAISE EXCEPTION 'Supervisor not found in your department';
  END IF;
  RETURN v_hod;
END;
$function$;

-- 1) HOD self-registration ---------------------------------------------------
-- Anyone can become a HOD tenant and choose their own secure password.
-- Each HOD only ever sees their own department's data (RLS enforced).
CREATE OR REPLACE FUNCTION public.hod_signup(p_full_name text, p_email text, p_phone text, p_password text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'auth'
AS $function$
DECLARE
  v_user_id   uuid := gen_random_uuid();
  v_instance  uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_email     text := lower(trim(p_email));
  v_emp_id    text;
BEGIN
  IF length(trim(p_full_name)) < 3 THEN
    RAISE EXCEPTION 'Enter a valid name';
  END IF;
  IF length(v_email) < 6 OR position('@' in v_email) = 0 THEN
    RAISE EXCEPTION 'Enter a valid email';
  END IF;
  IF length(regexp_replace(trim(p_phone), '[^0-9+]', '', 'g')) < 8 THEN
    RAISE EXCEPTION 'Enter a valid phone number';
  END IF;
  IF length(trim(p_password)) < 6 THEN
    RAISE EXCEPTION 'Password must be at least 6 characters';
  END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_email) THEN
    RAISE EXCEPTION 'An account already exists with this email';
  END IF;

  v_emp_id := 'THV-HOD-' || lpad(
    ((SELECT count(*)::int FROM public.profiles WHERE role = 'hod') + 1)::text,
    3, '0');

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
                        'full_name', trim(p_full_name),
                        'role', 'hod',
                        'phone', trim(p_phone)),
     now(), now(), '', '', '', '');

  -- Identity row — GoTrue requires it for password login (pattern 00010).
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

  -- handle_new_user trigger created the profile (role=hod, hod_id NULL).
  UPDATE public.profiles SET phone = trim(p_phone) WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'id', v_user_id::text,
    'emp_id', v_emp_id,
    'email', v_email,
    'status', 'created');
END;
$function$;

-- 2) admin_create_supervisor — tenant-scoped rewrite -------------------------
CREATE OR REPLACE FUNCTION public.admin_create_supervisor(p_name text, p_email text, p_phone text, p_password text, p_site_id text DEFAULT NULL::text, p_point_id text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'auth'
AS $function$
DECLARE
  v_caller  uuid := auth.uid();
  v_user_id uuid := gen_random_uuid();
  v_instance uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_email   text := lower(trim(p_email));
  v_emp_id  text;
BEGIN
  -- 1) Guard: authenticated HOD/admin only.
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF NOT public.has_role(ARRAY['hod', 'admin']) THEN
    RAISE EXCEPTION 'Only HOD accounts can create supervisors';
  END IF;

  -- 2) Input validation.
  IF length(trim(p_name)) < 3 THEN
    RAISE EXCEPTION 'Enter a valid supervisor name';
  END IF;
  IF length(v_email) < 6 OR position('@' in v_email) = 0 THEN
    RAISE EXCEPTION 'Enter a valid supervisor email';
  END IF;
  IF length(regexp_replace(trim(p_phone), '[^0-9+]', '', 'g')) < 8 THEN
    RAISE EXCEPTION 'Enter a valid supervisor phone number';
  END IF;
  IF length(trim(p_password)) < 6 THEN
    RAISE EXCEPTION 'Password must be at least 6 characters';
  END IF;

  -- 3) Idempotency: one account per email.
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_email) THEN
    RAISE EXCEPTION 'A supervisor already exists with this email';
  END IF;

  -- 4) TENANT: the site and point must belong to the caller's department.
  IF p_site_id IS NOT NULL AND p_site_id <> '' THEN
    IF NOT EXISTS (SELECT 1 FROM public.sites s WHERE s.id = p_site_id AND s.hod_id = v_caller) THEN
      RAISE EXCEPTION 'Site not found in your department';
    END IF;
  END IF;
  IF p_point_id IS NOT NULL AND p_point_id <> '' THEN
    IF NOT EXISTS (SELECT 1 FROM public.thavvu_points tp WHERE tp.id = p_point_id AND tp.hod_id = v_caller) THEN
      RAISE EXCEPTION 'Point not found in your department';
    END IF;
  END IF;

  -- 5) Human-readable employee id.
  v_emp_id := 'THV-SUP-' || lpad(
    ((SELECT count(*)::int FROM public.profiles WHERE role = 'supervisor') + 1)::text,
    3, '0');

  -- 6) Real email-confirmed auth user.
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

  -- 7) Identity row.
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

  -- 8) Trigger created the profile; stamp the tenant + phone.
  UPDATE public.profiles
     SET phone = trim(p_phone),
         hod_id = v_caller
   WHERE id = v_user_id;

  -- 9) Optional site + point assignment (both tenant-validated above).
  IF p_site_id IS NOT NULL AND p_site_id <> '' AND p_point_id IS NOT NULL AND p_point_id <> '' THEN
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
$function$;

-- 3) admin_update_supervisor -------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_update_supervisor(p_supervisor_id uuid, p_name text, p_phone text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'auth'
AS $function$
DECLARE
  v_hod uuid;
BEGIN
  v_hod := public.assert_my_supervisor(p_supervisor_id);

  IF length(trim(p_name)) < 3 THEN
    RAISE EXCEPTION 'Enter a valid supervisor name';
  END IF;
  IF length(regexp_replace(trim(p_phone), '[^0-9+]', '', 'g')) < 8 THEN
    RAISE EXCEPTION 'Enter a valid supervisor phone number';
  END IF;

  UPDATE public.profiles
     SET full_name = trim(p_name),
         phone = trim(p_phone),
         updated_at = now()
   WHERE id = p_supervisor_id;

  UPDATE auth.users
     SET raw_user_meta_data = raw_user_meta_data ||
          jsonb_build_object('full_name', trim(p_name), 'phone', trim(p_phone)),
         updated_at = now()
   WHERE id = p_supervisor_id;

  RETURN jsonb_build_object('id', p_supervisor_id::text, 'status', 'updated');
END;
$function$;

-- 4) admin_reset_supervisor_password -----------------------------------------
CREATE OR REPLACE FUNCTION public.admin_reset_supervisor_password(p_supervisor_id uuid, p_new_password text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'auth'
AS $function$
DECLARE
  v_hod uuid;
BEGIN
  v_hod := public.assert_my_supervisor(p_supervisor_id);

  IF length(trim(p_new_password)) < 6 THEN
    RAISE EXCEPTION 'Password must be at least 6 characters';
  END IF;

  UPDATE auth.users
     SET encrypted_password = extensions.crypt(trim(p_new_password), extensions.gen_salt('bf')),
         recovery_token = '',
         email_change_token_new = '',
         email_change = '',
         updated_at = now()
   WHERE id = p_supervisor_id;

  RETURN jsonb_build_object('id', p_supervisor_id::text, 'status', 'password_reset');
END;
$function$;

-- 5) admin_deactivate_supervisor / admin_reactivate_supervisor ---------------
CREATE OR REPLACE FUNCTION public.admin_deactivate_supervisor(p_supervisor_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'auth'
AS $function$
DECLARE
  v_hod uuid;
BEGIN
  v_hod := public.assert_my_supervisor(p_supervisor_id);

  UPDATE public.profiles
     SET is_active = false,
         updated_at = now()
   WHERE id = p_supervisor_id;

  -- Blocks sign-in at the GoTrue level.
  UPDATE auth.users
     SET banned_until = now(),
         updated_at = now()
   WHERE id = p_supervisor_id;

  -- End active point assignments so the point can be reassigned.
  UPDATE public.thavvu_point_assignments
     SET is_active = false,
         ended_at = now()
   WHERE supervisor_id = p_supervisor_id AND is_active = true;

  RETURN jsonb_build_object('id', p_supervisor_id::text, 'status', 'deactivated');
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_reactivate_supervisor(p_supervisor_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'auth'
AS $function$
DECLARE
  v_hod uuid;
BEGIN
  v_hod := public.assert_my_supervisor(p_supervisor_id);

  UPDATE public.profiles
     SET is_active = true,
         updated_at = now()
   WHERE id = p_supervisor_id;

  UPDATE auth.users
     SET banned_until = NULL,
         updated_at = now()
   WHERE id = p_supervisor_id;

  RETURN jsonb_build_object('id', p_supervisor_id::text, 'status', 'reactivated');
END;
$function$;

-- 6) approve_supervisor_registration — HOD assigns the password ---------------
CREATE OR REPLACE FUNCTION public.approve_supervisor_registration(p_request_id uuid, p_site_id text DEFAULT NULL::text, p_password text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'auth'
AS $function$
DECLARE
  v_caller    uuid := auth.uid();
  v_req       public.supervisor_registration_requests%ROWTYPE;
  v_user_id   uuid := gen_random_uuid();
  v_instance  uuid := '00000000-0000-0000-0000-000000000000'::uuid;
  v_emp_id    text;
  v_site_ok   boolean := false;
  v_point_id  text;
BEGIN
  -- 1) HOD guard.
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF NOT public.has_role(ARRAY['hod', 'admin']) THEN
    RAISE EXCEPTION 'Only HOD accounts can approve registrations';
  END IF;

  -- 2) The HOD chooses the supervisor's password (requirement: supervisors
  --    log in only with credentials assigned by their HOD).
  IF length(trim(COALESCE(p_password, ''))) < 6 THEN
    RAISE EXCEPTION 'Assign a password of at least 6 characters';
  END IF;

  -- 3) Lock the request row.
  SELECT * INTO v_req
  FROM public.supervisor_registration_requests
  WHERE id = p_request_id
  FOR UPDATE;
  IF v_req.id IS NULL THEN
    RAISE EXCEPTION 'Registration request not found';
  END IF;
  IF v_req.status <> 'pending' THEN
    RAISE EXCEPTION 'Registration is already %', v_req.status;
  END IF;

  -- 4) TENANT: the selected site must belong to the caller's department.
  IF p_site_id IS NOT NULL AND p_site_id <> '' THEN
    SELECT EXISTS (
      SELECT 1 FROM public.sites s WHERE s.id = p_site_id AND s.hod_id = v_caller
    ) INTO v_site_ok;
    IF NOT v_site_ok THEN
      RAISE EXCEPTION 'Selected site does not exist in your department';
    END IF;
  END IF;

  -- 5) Employee id: honor the requested one unless it is already taken.
  v_emp_id := v_req.emp_id;
  IF EXISTS (SELECT 1 FROM public.profiles WHERE emp_id = v_emp_id) THEN
    v_emp_id := 'THV-SUP-' || lpad(
      ((SELECT count(*)::int FROM public.profiles WHERE role = 'supervisor') + 1)::text,
      3, '0');
  END IF;

  -- 6) Real, email-confirmed auth user using the HOD-assigned password.
  INSERT INTO auth.users
    (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
     raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
     confirmation_token, recovery_token, email_change_token_new, email_change)
  VALUES
    (v_user_id, v_instance, 'authenticated', 'authenticated', v_req.email,
     extensions.crypt(trim(p_password), extensions.gen_salt('bf')), now(),
     jsonb_build_object('provider', 'email',
                        'providers', jsonb_build_array('email')),
     jsonb_build_object('emp_id', v_emp_id,
                        'full_name', v_req.full_name,
                        'role', 'supervisor',
                        'phone', v_req.phone),
     now(), now(), '', '', '', '');

  -- 7) Identity row.
  INSERT INTO auth.identities
    (id, user_id, identity_data, provider, provider_id, last_sign_in_at,
     created_at, updated_at)
  VALUES
    (v_user_id, v_user_id,
     jsonb_build_object('sub', v_user_id::text,
                        'email', v_req.email,
                        'email_verified', true,
                        'phone_verified', false),
     'email', v_user_id::text, now(), now(), now());

  -- 8) Trigger created the profile; stamp tenant + phone.
  UPDATE public.profiles
     SET phone = v_req.phone,
         hod_id = v_caller
   WHERE id = v_user_id;

  -- 9) Site membership (+ first AVAILABLE point when one exists).
  IF v_site_ok THEN
    INSERT INTO public.site_memberships
      (id, site_id, profile_id, role, is_active, assigned_by, assigned_at)
    VALUES
      (gen_random_uuid(), p_site_id, v_user_id, 'supervisor', true, v_caller, now())
    ON CONFLICT DO NOTHING;

    SELECT tp.id INTO v_point_id
    FROM public.thavvu_points tp
    WHERE tp.site_id = p_site_id
      AND tp.hod_id = v_caller
      AND tp.status IN ('active', 'granted')
      AND NOT EXISTS (
        SELECT 1 FROM public.thavvu_point_assignments tpa
        WHERE tpa.thavvu_point_id = tp.id AND tpa.is_active = true
      )
    ORDER BY tp.created_at
    LIMIT 1;
    IF v_point_id IS NOT NULL THEN
      INSERT INTO public.thavvu_point_assignments
        (id, thavvu_point_id, supervisor_id, site_id, assigned_by, is_active, assigned_at)
      VALUES
        (gen_random_uuid(), v_point_id, v_user_id, p_site_id, v_caller, true, now());
    END IF;
  END IF;

  -- 10) Mark the request reviewed + bound to this HOD's tenant.
  UPDATE public.supervisor_registration_requests
     SET status = 'approved',
         reviewed_by = v_caller,
         reviewed_at = now(),
         hod_id = v_caller,
         updated_at = now()
   WHERE id = v_req.id;

  RETURN jsonb_build_object(
    'id', v_user_id::text,
    'emp_id', v_emp_id,
    'email', v_req.email,
    'status', 'approved',
    'site_id', p_site_id);
END;
$function$;

-- 7) submit_supervisor_registration — request no longer carries a password ----
CREATE OR REPLACE FUNCTION public.submit_supervisor_registration(p_full_name text, p_emp_id text, p_phone text, p_site_name text, p_email text, p_password text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'auth'
AS $function$
DECLARE
  v_email text := lower(trim(p_email));
  v_emp   text := upper(trim(p_emp_id));
  v_row   public.supervisor_registration_requests;
BEGIN
  -- 1) Validation (mirrors the app-side checks).
  IF length(trim(p_full_name)) < 3 THEN
    RAISE EXCEPTION 'Enter a valid full name';
  END IF;
  IF length(v_emp) < 3 THEN
    RAISE EXCEPTION 'Enter a valid employee ID';
  END IF;
  IF length(regexp_replace(trim(p_phone), '[^0-9+]', '', 'g')) < 8 THEN
    RAISE EXCEPTION 'Enter a valid phone number';
  END IF;
  IF length(trim(p_site_name)) < 2 THEN
    RAISE EXCEPTION 'Enter your site / stock point';
  END IF;
  IF v_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
    RAISE EXCEPTION 'Enter a valid email address';
  END IF;

  -- 2) Idempotency against real accounts.
  IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_email) THEN
    RAISE EXCEPTION 'An account already exists with this email — please sign in';
  END IF;

  -- 3) Existing request for this email.
  SELECT * INTO v_row
  FROM public.supervisor_registration_requests
  WHERE email = v_email
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_row.id IS NOT NULL THEN
    IF v_row.status = 'approved' THEN
      RAISE EXCEPTION 'This email was already approved — please sign in with the password your HOD assigned';
    ELSIF v_row.status = 'pending' THEN
      RETURN jsonb_build_object('id', v_row.id::text, 'status', 'pending',
        'new', false, 'message', 'Your request is still awaiting HOD approval.');
    END IF;
    -- Rejected → revive with fresh details (keeps one row per email).
    UPDATE public.supervisor_registration_requests
       SET full_name = trim(p_full_name),
           emp_id = v_emp,
           phone = trim(p_phone),
           site_name = trim(p_site_name),
           password_hash = NULL,
           status = 'pending',
           admin_note = NULL,
           reviewed_by = NULL,
           reviewed_at = NULL,
           updated_at = now()
     WHERE id = v_row.id
     RETURNING * INTO v_row;
    RETURN jsonb_build_object('id', v_row.id::text, 'status', 'pending',
      'new', true, 'message', 'Request resubmitted for HOD approval.');
  END IF;

  -- 4) Insert WITHOUT a password — the HOD assigns it at approval.
  INSERT INTO public.supervisor_registration_requests
    (full_name, emp_id, phone, site_name, email)
  VALUES
    (trim(p_full_name), v_emp, trim(p_phone), trim(p_site_name), v_email)
  RETURNING * INTO v_row;

  RETURN jsonb_build_object('id', v_row.id::text, 'status', 'pending',
    'new', true, 'message', 'Request submitted for HOD approval.');
END;
$function$;

-- Password hash no longer needed in requests (HOD assigns at approval).
ALTER TABLE public.supervisor_registration_requests
  ALTER COLUMN password_hash DROP NOT NULL;

-- reject_supervisor_registration: bind the request to the rejecting HOD for
-- audit, so the intake pool stays tenant-accountable.
CREATE OR REPLACE FUNCTION public.reject_supervisor_registration(p_request_id uuid, p_reason text DEFAULT NULL::text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_caller uuid := auth.uid();
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF NOT public.has_role(ARRAY['hod', 'admin']) THEN
    RAISE EXCEPTION 'Only HOD accounts can reject registrations';
  END IF;

  UPDATE public.supervisor_registration_requests
     SET status = 'rejected',
         admin_note = COALESCE(p_reason, ''),
         reviewed_by = v_caller,
         reviewed_at = now(),
         hod_id = v_caller,
         updated_at = now()
   WHERE id = p_request_id
     AND status = 'pending';

  RETURN FOUND;
END;
$function$;
