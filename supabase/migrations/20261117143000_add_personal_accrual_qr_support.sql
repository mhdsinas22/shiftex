-- Migration: add_personal_accrual_qr_support
-- Extends customer_qr_tokens to support personal accrual-only QR passes ('accrual')
-- while keeping existing single-use claim QR tokens ('claim') completely compatible.

ALTER TABLE public.customer_qr_tokens
  ADD COLUMN IF NOT EXISTS token_purpose text NOT NULL DEFAULT 'claim',
  ADD COLUMN IF NOT EXISTS allow_deduction boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS revoked_at timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'customer_qr_tokens_purpose_check'
      AND conrelid = 'public.customer_qr_tokens'::regclass
  ) THEN
    ALTER TABLE public.customer_qr_tokens
      ADD CONSTRAINT customer_qr_tokens_purpose_check
      CHECK (token_purpose IN ('claim', 'accrual'));
  END IF;
END
$$;

ALTER TABLE public.customer_qr_tokens
  DROP CONSTRAINT IF EXISTS customer_qr_tokens_status_check;

ALTER TABLE public.customer_qr_tokens
  ADD CONSTRAINT customer_qr_tokens_status_check
  CHECK (status IN ('active', 'used', 'expired', 'revoked'));

CREATE INDEX IF NOT EXISTS customer_qr_tokens_user_purpose_status_idx
  ON public.customer_qr_tokens(user_id, token_purpose, status, expires_at DESC);

-- Ensure existing single-use claim QR issuer only matches/inserts 'claim' tokens.
CREATE OR REPLACE FUNCTION private.issue_customer_qr_token(p_user_id uuid)
RETURNS public.customer_qr_tokens
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_token public.customer_qr_tokens;
  v_short_code text;
  v_payload text;
  v_raw_hash text;
BEGIN
  IF p_user_id IS NULL OR p_user_id <> (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Invalid user context.';
  END IF;

  IF NOT private.is_approved_customer() THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_APPROVED: Only approved customers can generate claim QR codes.';
  END IF;

  -- Expire outdated single-use claim tokens first
  UPDATE public.customer_qr_tokens
  SET status = 'expired'
  WHERE user_id = p_user_id
    AND token_purpose = 'claim'
    AND status = 'active'
    AND expires_at <= now();

  -- Reuse active single-use claim token if it has more than 45 seconds remaining
  SELECT * INTO v_token
  FROM public.customer_qr_tokens
  WHERE user_id = p_user_id
    AND token_purpose = 'claim'
    AND status = 'active'
    AND expires_at > (now() + interval '45 seconds')
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN v_token;
  END IF;

  -- Generate new cryptographic single-use claim token
  v_raw_hash := encode(extensions.gen_random_bytes(16), 'hex');
  v_short_code := 'CLM-' || upper(substr(v_raw_hash, 1, 4)) || '-' || upper(substr(v_raw_hash, 5, 3));
  v_payload := 'SHIIFTEX:CLAIM:V1:' || v_short_code || ':' || upper(substr(v_raw_hash, 8, 12));

  INSERT INTO public.customer_qr_tokens (
    user_id,
    token_code,
    qr_payload,
    token_purpose,
    allow_deduction,
    status,
    expires_at
  ) VALUES (
    p_user_id,
    v_short_code,
    v_payload,
    'claim',
    true,
    'active',
    now() + interval '5 minutes'
  )
  RETURNING * INTO v_token;

  RETURN v_token;
END;
$$;

-- Issue or reuse an accrual-only personal QR token (cannot deduct or charge points).
CREATE OR REPLACE FUNCTION private.issue_customer_personal_qr(
  p_user_id uuid,
  p_force_regenerate boolean DEFAULT false
)
RETURNS public.customer_qr_tokens
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_token public.customer_qr_tokens;
  v_short_code text;
  v_payload text;
  v_raw_hash text;
BEGIN
  IF p_user_id IS NULL OR p_user_id <> (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Invalid user context.';
  END IF;

  IF NOT private.is_approved_customer() THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_APPROVED: Only approved customers can access a personal accrual QR.';
  END IF;

  -- Ensure wallet and membership code exist idempotently even on direct route entry
  PERFORM private.ensure_wallet_and_unlock_allocations(p_user_id);

  -- Mark outdated accrual tokens as expired
  UPDATE public.customer_qr_tokens
  SET status = 'expired'
  WHERE user_id = p_user_id
    AND token_purpose = 'accrual'
    AND status = 'active'
    AND expires_at <= now();

  IF COALESCE(p_force_regenerate, false) THEN
    UPDATE public.customer_qr_tokens
    SET
      status = 'revoked',
      revoked_at = now()
    WHERE user_id = p_user_id
      AND token_purpose = 'accrual'
      AND status = 'active';
  ELSE
    SELECT * INTO v_token
    FROM public.customer_qr_tokens
    WHERE user_id = p_user_id
      AND token_purpose = 'accrual'
      AND allow_deduction = false
      AND status = 'active'
      AND expires_at > (now() + interval '60 seconds')
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
      RETURN v_token;
    END IF;
  END IF;

  -- Opaque short-lived cryptographic accrual token: never encodes email, phone, password, or balances
  v_raw_hash := encode(extensions.gen_random_bytes(16), 'hex');
  v_short_code := 'ACC-' || upper(substr(v_raw_hash, 1, 4)) || '-' || upper(substr(v_raw_hash, 5, 4));
  v_payload := 'SHIIFTEX:ACCRUAL:V1:' || v_short_code || ':' || upper(substr(v_raw_hash, 9, 16));

  INSERT INTO public.customer_qr_tokens (
    user_id,
    token_code,
    qr_payload,
    token_purpose,
    allow_deduction,
    status,
    expires_at
  ) VALUES (
    p_user_id,
    v_short_code,
    v_payload,
    'accrual',
    false,
    'active',
    now() + interval '15 minutes'
  )
  RETURNING * INTO v_token;

  RETURN v_token;
END;
$$;

REVOKE ALL ON FUNCTION private.issue_customer_personal_qr(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.issue_customer_personal_qr(uuid, boolean) TO authenticated;

-- Revoke any active personal accrual QR tokens belonging to the authenticated customer.
CREATE OR REPLACE FUNCTION private.revoke_customer_personal_qr(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_revoked_count integer := 0;
BEGIN
  IF p_user_id IS NULL OR p_user_id <> (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Invalid user context.';
  END IF;

  IF NOT private.is_approved_customer() THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_APPROVED: Only approved customers can revoke personal accrual QR codes.';
  END IF;

  UPDATE public.customer_qr_tokens
  SET
    status = 'revoked',
    revoked_at = now()
  WHERE user_id = p_user_id
    AND token_purpose = 'accrual'
    AND status = 'active';

  GET DIAGNOSTICS v_revoked_count = ROW_COUNT;
  RETURN v_revoked_count;
END;
$$;

REVOKE ALL ON FUNCTION private.revoke_customer_personal_qr(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.revoke_customer_personal_qr(uuid) TO authenticated;

-- Public SECURITY INVOKER RPC for Personal Accrual QR Display page.
CREATE OR REPLACE FUNCTION public.get_customer_personal_qr(
  p_force_regenerate boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
  v_token public.customer_qr_tokens;
  v_full_name text;
  v_customer_code text;
  v_membership_tier text;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  v_token := private.issue_customer_personal_qr(v_uid, p_force_regenerate);

  SELECT customer_code, membership_tier
  INTO v_customer_code, v_membership_tier
  FROM public.customer_wallets
  WHERE user_id = v_uid;

  SELECT full_name
  INTO v_full_name
  FROM public.profiles
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'customer_id', v_uid,
    'full_name', COALESCE(NULLIF(trim(v_full_name), ''), 'SHIIFTEX Member'),
    'membership_id', COALESCE(v_customer_code, 'SHFT-' || upper(substr(replace(v_uid::text, '-', ''), 1, 4))),
    'membership_tier', COALESCE(NULLIF(trim(v_membership_tier), ''), 'Pebble Black Member'),
    'token_id', v_token.id,
    'token_code', v_token.token_code,
    'qr_payload', v_token.qr_payload,
    'token_purpose', v_token.token_purpose,
    'allow_deduction', v_token.allow_deduction,
    'status', v_token.status,
    'expires_at', v_token.expires_at,
    'created_at', v_token.created_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_personal_qr(boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_personal_qr(boolean) TO authenticated, service_role;

-- Public SECURITY INVOKER RPC to revoke active personal accrual QR tokens.
CREATE OR REPLACE FUNCTION public.revoke_customer_personal_qr()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
  v_revoked_count integer;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  v_revoked_count := private.revoke_customer_personal_qr(v_uid);

  RETURN jsonb_build_object(
    'revoked', v_revoked_count > 0,
    'revoked_count', v_revoked_count,
    'revoked_at', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.revoke_customer_personal_qr() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_customer_personal_qr() TO authenticated, service_role;
