-- ============================================================================
-- Migration 00033: HOD login owner-approval gate (Telegram bot).
-- ============================================================================

-- gen_random_bytes() (used for request tokens) lives in pgcrypto.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.hod_login_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_email text NOT NULL,
  requester_id uuid,
  owner_phone text NOT NULL DEFAULT '7207507251',
  channel text NOT NULL DEFAULT 'telegram', -- telegram | whatsapp
  status text NOT NULL DEFAULT 'pending', -- pending | approved | rejected
  request_token text NOT NULL UNIQUE,
  requested_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  response text
);

CREATE INDEX IF NOT EXISTS idx_hod_login_approvals_email ON public.hod_login_approvals(requester_email, status);
CREATE INDEX IF NOT EXISTS idx_hod_login_approvals_token ON public.hod_login_approvals(request_token);

ALTER TABLE public.hod_login_approvals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "hod_login_approvals_auth_select" ON public.hod_login_approvals;
CREATE POLICY "hod_login_approvals_auth_select" ON public.hod_login_approvals FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ---------------------------------------------------------------------------
-- telegram_owner_config — the owner's bot chat id (single row, id=1)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.telegram_owner_config (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  chat_id text,
  username text,
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.telegram_owner_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "telegram_owner_config_auth_select" ON public.telegram_owner_config;
CREATE POLICY "telegram_owner_config_auth_select" ON public.telegram_owner_config FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ---------------------------------------------------------------------------
-- request_hod_approval(email) -> jsonb { id, token, status, new }
-- Reuses an existing pending request, or an approved request from the last
-- 24 hours (repeat logins skip the gate), otherwise creates a new pending one.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_hod_approval(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.hod_login_approvals;
BEGIN
  SELECT * INTO v_row
  FROM public.hod_login_approvals
  WHERE requester_email = p_email AND status = 'pending'
  ORDER BY requested_at DESC
  LIMIT 1;
  IF v_row.id IS NOT NULL THEN
    RETURN jsonb_build_object('id', v_row.id::text, 'token', v_row.request_token,
                              'status', v_row.status, 'new', false);
  END IF;

  SELECT * INTO v_row
  FROM public.hod_login_approvals
  WHERE requester_email = p_email AND status = 'approved'
    AND responded_at >= now() - interval '24 hours'
  ORDER BY responded_at DESC
  LIMIT 1;
  IF v_row.id IS NOT NULL THEN
    RETURN jsonb_build_object('id', v_row.id::text, 'token', v_row.request_token,
                              'status', v_row.status, 'new', false);
  END IF;

  INSERT INTO public.hod_login_approvals
    (requester_email, requester_id, request_token)
  VALUES (p_email, auth.uid(),
          substr(md5(random()::text || clock_timestamp()::text || gen_random_uuid()::text), 1, 18))
  RETURNING * INTO v_row;

  RETURN jsonb_build_object('id', v_row.id::text, 'token', v_row.request_token,
                            'status', v_row.status, 'new', true);
END $$;

-- ---------------------------------------------------------------------------
-- check_hod_approval(token) -> jsonb { status, response }
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_hod_approval(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.hod_login_approvals;
BEGIN
  SELECT * INTO v_row
  FROM public.hod_login_approvals
  WHERE request_token = p_token
  LIMIT 1;
  IF v_row.id IS NULL THEN
    RETURN jsonb_build_object('status', 'unknown', 'response', null);
  END IF;
  RETURN jsonb_build_object('status', v_row.status, 'response', v_row.response);
END $$;

-- ---------------------------------------------------------------------------
-- approve_hod_login_request(token, response) -> boolean
-- Called by the Telegram bot webhook when the owner replies (e.g.
-- "okay send"), and by the demo simulator.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_hod_login_request(p_token text, p_response text DEFAULT 'okay')
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.hod_login_approvals
  SET status = 'approved',
      responded_at = now(),
      response = p_response
  WHERE request_token = p_token AND status = 'pending';
  RETURN FOUND;
END $$;

-- ---------------------------------------------------------------------------
-- record_owner_chat / get_owner_chat — used by the bot to auto-discover the
-- owner's chat id when they send /start, and to read it back for DMs.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_owner_chat(p_chat_id text, p_username text DEFAULT null)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.telegram_owner_config (id, chat_id, username, updated_at)
  VALUES (1, p_chat_id, p_username, now())
  ON CONFLICT (id) DO UPDATE
    SET chat_id = EXCLUDED.chat_id,
        username = COALESCE(EXCLUDED.username, telegram_owner_config.username),
        updated_at = now();
  RETURN true;
END $$;

CREATE OR REPLACE FUNCTION public.get_owner_chat()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_chat text;
BEGIN
  SELECT chat_id INTO v_chat FROM public.telegram_owner_config WHERE id = 1;
  RETURN v_chat;
END $$;
