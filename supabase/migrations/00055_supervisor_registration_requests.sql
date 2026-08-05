-- ============================================================================
-- Migration 00055: Supervisor self-registration with HOD approval.
--
-- Problem (seen live): the login screen's "Create Account" called
-- Supabase Auth signUp directly with fake metadata. It 400'd
-- ("Email address ... is invalid") and, even when it succeeded, created an
-- unapproved auth user whose profile was never tied to a site, so the
-- supervisor could never actually work.
--
-- Fix: registration no longer creates an auth user. The visitor submits a
-- REQUEST (identity fields + a bcrypt password hash — never plaintext).
-- The HOD reviews requests in a dedicated approvals module and, on
-- approval, a SECURITY DEFINER RPC provisions a REAL, email-confirmed
-- auth user using the stored hash (so the password the supervisor chose
-- works immediately), plus profile, site membership and — when a site is
-- picked — a Thavvu Point assignment.
--
-- Reads are RLS-scoped to HOD/admin only; ALL writes go through the RPCs.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.supervisor_registration_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name     text NOT NULL,
  emp_id        text NOT NULL,
  phone         text NOT NULL,
  site_name     text NOT NULL DEFAULT '',
  email         text NOT NULL,
  password_hash text NOT NULL,             -- bcrypt (extensions.crypt), never plaintext
  status        text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_note    text,
  reviewed_by   uuid REFERENCES public.profiles(id),
  reviewed_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT supervisor_registration_requests_email_key UNIQUE (email)
);

CREATE INDEX IF NOT EXISTS idx_supervisor_reg_requests_status
  ON public.supervisor_registration_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_supervisor_reg_requests_email
  ON public.supervisor_registration_requests(email);

-- ---------------------------------------------------------------------------
-- RLS: HOD/admin can read requests (drives the approvals screen + realtime).
-- No INSERT/UPDATE/DELETE policies — writes happen only via the RPCs below.
-- ---------------------------------------------------------------------------
ALTER TABLE public.supervisor_registration_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "supervisor_reg_requests_select_hod" ON public.supervisor_registration_requests;
CREATE POLICY "supervisor_reg_requests_select_hod"
  ON public.supervisor_registration_requests FOR SELECT
  USING (public.has_role(ARRAY['hod', 'admin']));

-- Realtime: the HOD approvals screen refreshes instantly when a supervisor
-- submits a request.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime'
                   AND schemaname = 'public'
                   AND tablename = 'supervisor_registration_requests') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.supervisor_registration_requests;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- submit_supervisor_registration — called by ANONYMOUS visitors (and signed
-- in users) from the login screen. Validates input, rejects emails that
-- already have an account, revives a previously rejected request, and stores
-- only a bcrypt hash of the chosen password.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_supervisor_registration(
  p_full_name text,
  p_emp_id text,
  p_phone text,
  p_site_name text,
  p_email text,
  p_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, auth
AS $$
DECLARE
  v_email text := lower(trim(p_email));
  v_emp   text := upper(trim(p_emp_id));
  v_hash  text;
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
  IF length(p_password) < 6 THEN
    RAISE EXCEPTION 'Password must be at least 6 characters';
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
      RAISE EXCEPTION 'This email was already approved — please sign in with the password you set';
    ELSIF v_row.status = 'pending' THEN
      RETURN jsonb_build_object('id', v_row.id::text, 'status', 'pending',
        'new', false, 'message', 'Your request is still awaiting HOD approval.');
    END IF;
    -- Rejected → revive with fresh details (keeps one row per email).
    v_hash := extensions.crypt(p_password, extensions.gen_salt('bf'));
    UPDATE public.supervisor_registration_requests
       SET full_name = trim(p_full_name),
           emp_id = v_emp,
           phone = trim(p_phone),
           site_name = trim(p_site_name),
           password_hash = v_hash,
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

  v_hash := extensions.crypt(p_password, extensions.gen_salt('bf'));
  INSERT INTO public.supervisor_registration_requests
    (full_name, emp_id, phone, site_name, email, password_hash)
  VALUES
    (trim(p_full_name), v_emp, trim(p_phone), trim(p_site_name), v_email, v_hash)
  RETURNING * INTO v_row;

  RETURN jsonb_build_object('id', v_row.id::text, 'status', 'pending',
    'new', true, 'message', 'Request submitted for HOD approval.');
END $$;

REVOKE ALL ON FUNCTION public.submit_supervisor_registration(text, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_supervisor_registration(text, text, text, text, text, text) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- approve_supervisor_registration — HOD-only. Provisions the real auth user
-- with the stored password hash (pattern from 00034 + 00009/00014: token
-- columns non-NULL so GoTrue can scan the row), the identity row (00010),
-- profile via the on_auth_user_created trigger, then site membership +
-- Thavvu Point assignment when a site is chosen.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_supervisor_registration(
  p_request_id uuid,
  p_site_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, auth
AS $$
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

  -- 2) Lock the request row.
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

  -- 3) Site validation.
  IF p_site_id IS NOT NULL AND p_site_id <> '' THEN
    SELECT EXISTS (SELECT 1 FROM public.sites WHERE id = p_site_id) INTO v_site_ok;
    IF NOT v_site_ok THEN
      RAISE EXCEPTION 'Selected site does not exist';
    END IF;
  END IF;

  -- 4) Employee id: honor the requested one unless it is already taken.
  v_emp_id := v_req.emp_id;
  IF EXISTS (SELECT 1 FROM public.profiles WHERE emp_id = v_emp_id) THEN
    v_emp_id := 'THV-SUP-' || lpad(
      ((SELECT count(*)::int FROM public.profiles WHERE role = 'supervisor') + 1)::text,
      3, '0');
  END IF;

  -- 5) Real, email-confirmed auth user using the supervisor's chosen
  --    password (stored as a bcrypt hash — same format as auth.users).
  INSERT INTO auth.users
    (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
     raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
     confirmation_token, recovery_token, email_change_token_new, email_change)
  VALUES
    (v_user_id, v_instance, 'authenticated', 'authenticated', v_req.email,
     v_req.password_hash, now(),
     jsonb_build_object('provider', 'email',
                        'providers', jsonb_build_array('email')),
     jsonb_build_object('emp_id', v_emp_id,
                        'full_name', v_req.full_name,
                        'role', 'supervisor',
                        'phone', v_req.phone),
     now(), now(), '', '', '', '');

  -- 6) Identity row — GoTrue requires it for password login (pattern 00010).
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

  -- 7) The on_auth_user_created trigger created the profile; set phone.
  UPDATE public.profiles SET phone = v_req.phone WHERE id = v_user_id;

  -- 8) Site membership (+ first AVAILABLE point when one exists). A point
  --    has one active supervisor (idx_tp_assignments_active_unique), so only
  --    points with no active assignment are considered. No ON CONFLICT here:
  --    swallowing a unique violation hid this bug for a whole debug session.
  IF v_site_ok THEN
    INSERT INTO public.site_memberships
      (id, site_id, profile_id, role, is_active, assigned_by, assigned_at)
    VALUES
      (gen_random_uuid(), p_site_id, v_user_id, 'supervisor', true, v_caller, now())
    ON CONFLICT DO NOTHING;

    SELECT tp.id INTO v_point_id
    FROM public.thavvu_points tp
    WHERE tp.site_id = p_site_id
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

  -- 9) Mark the request reviewed.
  UPDATE public.supervisor_registration_requests
     SET status = 'approved',
         reviewed_by = v_caller,
         reviewed_at = now(),
         updated_at = now()
   WHERE id = v_req.id;

  RETURN jsonb_build_object(
    'id', v_user_id::text,
    'emp_id', v_emp_id,
    'email', v_req.email,
    'status', 'approved',
    'site_id', p_site_id);
END $$;

REVOKE ALL ON FUNCTION public.approve_supervisor_registration(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.approve_supervisor_registration(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- reject_supervisor_registration — HOD-only; records an optional reason.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reject_supervisor_registration(
  p_request_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;
  IF NOT public.has_role(ARRAY['hod', 'admin']) THEN
    RAISE EXCEPTION 'Only HOD accounts can reject registrations';
  END IF;

  UPDATE public.supervisor_registration_requests
     SET status = 'rejected',
         admin_note = p_reason,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         updated_at = now()
   WHERE id = p_request_id AND status = 'pending';
  RETURN FOUND;
END $$;

REVOKE ALL ON FUNCTION public.reject_supervisor_registration(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reject_supervisor_registration(uuid, text) TO authenticated;
