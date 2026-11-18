-- Migration: create_reward_claims_and_reservation_flow
-- Implements atomic single-use claim reservations, expiry release, and Admin POS scanner compatibility.

-- 1. Add reserved_points column to customer_wallets (no duplicate wallet table)
ALTER TABLE public.customer_wallets
  ADD COLUMN IF NOT EXISTS reserved_points integer NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'customer_wallets_reserved_points_check'
      AND conrelid = 'public.customer_wallets'::regclass
  ) THEN
    ALTER TABLE public.customer_wallets
      ADD CONSTRAINT customer_wallets_reserved_points_check
      CHECK (reserved_points >= 0);
  END IF;
END
$$;

-- 2. Create reward_claims table linked 1:1 with customer_qr_tokens
CREATE TABLE IF NOT EXISTS public.reward_claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  qr_token_id uuid UNIQUE REFERENCES public.customer_qr_tokens(id) ON DELETE SET NULL,
  claim_reference text NOT NULL UNIQUE,
  token_hash text NOT NULL UNIQUE,
  points integer NOT NULL CHECK (points > 0),
  points_to_inr_rate numeric(10,4) NOT NULL CHECK (points_to_inr_rate > 0),
  discount_amount numeric(12,2) NOT NULL CHECK (discount_amount > 0),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'redeemed', 'expired', 'cancelled')),
  idempotency_key text UNIQUE,
  expires_at timestamptz NOT NULL,
  redeemed_at timestamptz,
  redeemed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  redeemed_by_email text,
  bill_number text,
  branch_name text,
  transaction_id uuid REFERENCES public.point_transactions(id) ON DELETE SET NULL,
  released_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reward_claims_user_status_expires_idx
  ON public.reward_claims(user_id, status, expires_at DESC);

CREATE INDEX IF NOT EXISTS reward_claims_qr_token_idx
  ON public.reward_claims(qr_token_id)
  WHERE qr_token_id IS NOT NULL;

ALTER TABLE public.reward_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_claims FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.reward_claims FROM PUBLIC, anon;
GRANT SELECT ON public.reward_claims TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'reward_claims'
      AND policyname = 'reward_claims_select_own_or_admin'
  ) THEN
    CREATE POLICY reward_claims_select_own_or_admin
      ON public.reward_claims
      FOR SELECT
      TO authenticated
      USING ((SELECT auth.uid()) = user_id OR (SELECT private.is_admin()));
  END IF;
END
$$;

-- 3. Atomically release any expired pending claim reservations back to available_points
CREATE OR REPLACE FUNCTION private.release_expired_claim_reservations(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_claim record;
  v_released_points integer := 0;
  v_released_count integer := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN 0;
  END IF;

  IF p_user_id <> (SELECT auth.uid()) AND NOT private.is_admin() THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Invalid user context.';
  END IF;

  -- Lock wallet first to maintain deterministic global lock ordering
  PERFORM 1
  FROM public.customer_wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  FOR v_claim IN
    SELECT id, qr_token_id, points
    FROM public.reward_claims
    WHERE user_id = p_user_id
      AND status = 'pending'
      AND expires_at <= now()
    FOR UPDATE
  LOOP
    UPDATE public.reward_claims
    SET
      status = 'expired',
      released_at = now(),
      updated_at = now()
    WHERE id = v_claim.id;

    IF v_claim.qr_token_id IS NOT NULL THEN
      UPDATE public.customer_qr_tokens
      SET
        status = 'expired',
        allow_deduction = false
      WHERE id = v_claim.qr_token_id
        AND status = 'active';
    END IF;

    v_released_points := v_released_points + v_claim.points;
    v_released_count := v_released_count + 1;
  END LOOP;

  -- Also expire any orphaned active claim tokens past expiry
  UPDATE public.customer_qr_tokens
  SET
    status = 'expired',
    allow_deduction = false
  WHERE user_id = p_user_id
    AND token_purpose = 'claim'
    AND status = 'active'
    AND expires_at <= now();

  IF v_released_points > 0 THEN
    UPDATE public.customer_wallets
    SET
      available_points = available_points + v_released_points,
      reserved_points = GREATEST(0, reserved_points - v_released_points),
      updated_at = now()
    WHERE user_id = p_user_id;
  END IF;

  RETURN v_released_count;
END;
$$;

REVOKE ALL ON FUNCTION private.release_expired_claim_reservations(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.release_expired_claim_reservations(uuid) TO authenticated;

-- 4. Update wallet unlock helpers to also release expired claim reservations cleanly
CREATE OR REPLACE FUNCTION private.ensure_wallet_and_unlock_allocations(p_user_id uuid)
RETURNS public.customer_wallets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_wallet public.customer_wallets;
  v_code text;
  v_alloc record;
  v_unlocked_sum integer := 0;
BEGIN
  IF p_user_id IS NULL OR p_user_id <> (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Invalid user context.';
  END IF;

  v_code := 'SHFT-' || upper(substr(replace(p_user_id::text, '-', ''), 1, 4));

  INSERT INTO public.customer_wallets (
    user_id,
    customer_code,
    membership_tier
  ) VALUES (
    p_user_id,
    v_code,
    'Pebble Black Member'
  )
  ON CONFLICT (user_id) DO NOTHING;

  -- Release expired pending claims back to instant available balance
  PERFORM private.release_expired_claim_reservations(p_user_id);

  -- Transfer any matured 7-day locked allocations into instant available balance
  FOR v_alloc IN
    SELECT id, points, description
    FROM public.point_allocations
    WHERE user_id = p_user_id
      AND status = 'locked'
      AND unlock_at <= now()
    FOR UPDATE
  LOOP
    UPDATE public.point_allocations
    SET
      status = 'unlocked',
      unlocked_at = now()
    WHERE id = v_alloc.id;

    v_unlocked_sum := v_unlocked_sum + v_alloc.points;

    INSERT INTO public.point_transactions (
      user_id,
      transaction_type,
      title,
      description,
      points_delta,
      is_locked_allocation,
      reference_id,
      metadata
    ) VALUES (
      p_user_id,
      'streak_unlock',
      'Streak Points Unlocked',
      v_alloc.description,
      v_alloc.points,
      false,
      v_alloc.id,
      jsonb_build_object('unlocked_from_allocation', v_alloc.id)
    );
  END LOOP;

  IF v_unlocked_sum > 0 THEN
    UPDATE public.customer_wallets
    SET
      locked_points = GREATEST(0, locked_points - v_unlocked_sum),
      available_points = available_points + v_unlocked_sum,
      lifetime_earned_points = lifetime_earned_points + v_unlocked_sum,
      updated_at = now()
    WHERE user_id = p_user_id;

    UPDATE public.daily_streak_checkins
    SET
      is_unlocked = true,
      unlocked_at = COALESCE(unlocked_at, now())
    WHERE user_id = p_user_id
      AND is_unlocked = false
      AND unlock_at <= now();
  END IF;

  SELECT * INTO v_wallet
  FROM public.customer_wallets
  WHERE user_id = p_user_id;

  RETURN v_wallet;
END;
$$;

CREATE OR REPLACE FUNCTION private.admin_sync_customer_wallet(p_user_id uuid)
RETURNS public.customer_wallets
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_wallet public.customer_wallets;
  v_code text;
  v_alloc record;
  v_unlocked_sum integer := 0;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_CUSTOMER: Customer ID is required.';
  END IF;

  v_code := 'SHFT-' || upper(substr(replace(p_user_id::text, '-', ''), 1, 4));

  INSERT INTO public.customer_wallets (
    user_id,
    customer_code,
    membership_tier
  ) VALUES (
    p_user_id,
    v_code,
    'Pebble Black Member'
  )
  ON CONFLICT (user_id) DO NOTHING;

  PERFORM private.release_expired_claim_reservations(p_user_id);

  FOR v_alloc IN
    SELECT id, points, description
    FROM public.point_allocations
    WHERE user_id = p_user_id
      AND status = 'locked'
      AND unlock_at <= now()
    FOR UPDATE
  LOOP
    UPDATE public.point_allocations
    SET
      status = 'unlocked',
      unlocked_at = now()
    WHERE id = v_alloc.id;

    v_unlocked_sum := v_unlocked_sum + v_alloc.points;

    INSERT INTO public.point_transactions (
      user_id,
      transaction_type,
      title,
      description,
      points_delta,
      is_locked_allocation,
      reference_id,
      metadata
    ) VALUES (
      p_user_id,
      'streak_unlock',
      'Locked Points Unlocked',
      v_alloc.description,
      v_alloc.points,
      false,
      v_alloc.id,
      jsonb_build_object('unlocked_from_allocation', v_alloc.id)
    );
  END LOOP;

  IF v_unlocked_sum > 0 THEN
    UPDATE public.customer_wallets
    SET
      locked_points = GREATEST(0, locked_points - v_unlocked_sum),
      available_points = available_points + v_unlocked_sum,
      lifetime_earned_points = lifetime_earned_points + v_unlocked_sum,
      updated_at = now()
    WHERE user_id = p_user_id;

    UPDATE public.daily_streak_checkins
    SET
      is_unlocked = true,
      unlocked_at = COALESCE(unlocked_at, now())
    WHERE user_id = p_user_id
      AND is_unlocked = false
      AND unlock_at <= now();
  END IF;

  SELECT * INTO v_wallet
  FROM public.customer_wallets
  WHERE user_id = p_user_id;

  RETURN v_wallet;
END;
$$;

-- 5. Internal helper to format a reward claim + wallet JSON payload consistently
CREATE OR REPLACE FUNCTION private.serialize_reward_claim_response(
  p_claim public.reward_claims,
  p_qr_payload text,
  p_wallet public.customer_wallets
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'claim', CASE
      WHEN p_claim.id IS NULL THEN NULL
      ELSE jsonb_build_object(
        'id', p_claim.id,
        'user_id', p_claim.user_id,
        'qr_token_id', p_claim.qr_token_id,
        'claim_reference', p_claim.claim_reference,
        'qr_payload', p_qr_payload,
        'points', p_claim.points,
        'points_to_inr_rate', p_claim.points_to_inr_rate,
        'discount_amount', p_claim.discount_amount,
        'status', p_claim.status,
        'expires_at', p_claim.expires_at,
        'created_at', p_claim.created_at,
        'redeemed_at', p_claim.redeemed_at,
        'bill_number', p_claim.bill_number,
        'branch_name', p_claim.branch_name,
        'released_at', p_claim.released_at
      )
    END,
    'wallet', jsonb_build_object(
      'customer_code', p_wallet.customer_code,
      'membership_tier', p_wallet.membership_tier,
      'available_points', p_wallet.available_points,
      'reserved_points', p_wallet.reserved_points,
      'locked_points', p_wallet.locked_points,
      'lifetime_earned_points', p_wallet.lifetime_earned_points,
      'lifetime_redeemed_points', p_wallet.lifetime_redeemed_points
    )
  );
$$;

REVOKE ALL ON FUNCTION private.serialize_reward_claim_response(public.reward_claims, text, public.customer_wallets) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.serialize_reward_claim_response(public.reward_claims, text, public.customer_wallets) TO authenticated;

-- 6. Private transactional claim generator with atomic reservation
CREATE OR REPLACE FUNCTION private.create_reward_claim_for_customer(
  p_user_id uuid,
  p_points integer,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_points integer := COALESCE(p_points, 0);
  v_idem text := NULLIF(trim(COALESCE(p_idempotency_key, '')), '');
  v_wallet public.customer_wallets;
  v_rate numeric(10,4);
  v_discount numeric(12,2);
  v_existing_claim public.reward_claims;
  v_existing_payload text;
  v_raw_hash text;
  v_claim_ref text;
  v_payload text;
  v_token_hash text;
  v_expires_at timestamptz;
  v_token public.customer_qr_tokens;
  v_claim public.reward_claims;
BEGIN
  IF p_user_id IS NULL OR p_user_id <> (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Invalid user context.';
  END IF;

  IF NOT private.is_approved_customer() THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_APPROVED: Only approved customers can claim rewards.';
  END IF;

  IF v_points <= 0 OR v_points > 1000000 THEN
    RAISE EXCEPTION 'INVALID_AMOUNT: Select at least 1 instant point to claim.';
  END IF;

  -- Ensure wallet exists, mature allocations unlocked, and expired claims released
  PERFORM private.ensure_wallet_and_unlock_allocations(p_user_id);

  -- Lock customer wallet first to serialize concurrent claim requests
  SELECT * INTO v_wallet
  FROM public.customer_wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  -- Idempotency check so double-taps / retries return the exact same pending claim
  IF v_idem IS NOT NULL THEN
    SELECT * INTO v_existing_claim
    FROM public.reward_claims
    WHERE user_id = p_user_id
      AND idempotency_key = v_idem
    LIMIT 1;

    IF FOUND THEN
      SELECT qr_payload INTO v_existing_payload
      FROM public.customer_qr_tokens
      WHERE id = v_existing_claim.qr_token_id;

      RETURN private.serialize_reward_claim_response(
        v_existing_claim,
        v_existing_payload,
        v_wallet
      );
    END IF;
  END IF;

  -- Validate against instant unreserved available points only (never locked_points)
  IF v_wallet.available_points < v_points THEN
    RAISE EXCEPTION 'INSUFFICIENT_BALANCE: You have % instant points available to claim.', v_wallet.available_points;
  END IF;

  SELECT COALESCE(points_to_inr_rate, 0.1000)
  INTO v_rate
  FROM public.reward_settings
  WHERE singleton_key = 'global'
  LIMIT 1;

  v_rate := COALESCE(v_rate, 0.1000);
  IF v_rate <= 0 THEN
    RAISE EXCEPTION 'INVALID_RATE: Reward conversion rate is invalid.';
  END IF;

  v_discount := round((v_points * v_rate)::numeric, 2);
  IF v_discount <= 0 THEN
    RAISE EXCEPTION 'INVALID_AMOUNT: Selected points must produce at least ₹0.01 discount.';
  END IF;

  -- Cryptographic opaque token matching Admin POS scanner (verify_customer_qr_for_pos)
  v_raw_hash := encode(extensions.gen_random_bytes(16), 'hex');
  v_claim_ref := 'CLM-' || upper(substr(v_raw_hash, 1, 4)) || '-' || upper(substr(v_raw_hash, 5, 3));
  v_payload := 'SHIIFTEX:CLAIM:V1:' || v_claim_ref || ':' || upper(substr(v_raw_hash, 8, 12));
  v_token_hash := encode(extensions.digest(v_payload, 'sha256'), 'hex');
  v_expires_at := now() + interval '5 minutes';

  -- Reserve points atomically without deducting permanently
  UPDATE public.customer_wallets
  SET
    available_points = available_points - v_points,
    reserved_points = reserved_points + v_points,
    updated_at = now()
  WHERE user_id = p_user_id
  RETURNING * INTO v_wallet;

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
    v_claim_ref,
    v_payload,
    'claim',
    true,
    'active',
    v_expires_at
  )
  RETURNING * INTO v_token;

  INSERT INTO public.reward_claims (
    user_id,
    qr_token_id,
    claim_reference,
    token_hash,
    points,
    points_to_inr_rate,
    discount_amount,
    status,
    idempotency_key,
    expires_at
  ) VALUES (
    p_user_id,
    v_token.id,
    v_claim_ref,
    v_token_hash,
    v_points,
    v_rate,
    v_discount,
    'pending',
    v_idem,
    v_expires_at
  )
  RETURNING * INTO v_claim;

  RETURN private.serialize_reward_claim_response(
    v_claim,
    v_payload,
    v_wallet
  );
END;
$$;

REVOKE ALL ON FUNCTION private.create_reward_claim_for_customer(uuid, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.create_reward_claim_for_customer(uuid, integer, text) TO authenticated;

-- 7. Private explicit cancel helper (releases reservation cleanly if still pending)
CREATE OR REPLACE FUNCTION private.cancel_reward_claim_for_customer(
  p_user_id uuid,
  p_claim_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_wallet public.customer_wallets;
  v_claim public.reward_claims;
  v_qr_payload text;
BEGIN
  IF p_user_id IS NULL OR p_user_id <> (SELECT auth.uid()) THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Invalid user context.';
  END IF;

  IF NOT private.is_approved_customer() THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_APPROVED: Customer account is not approved.';
  END IF;

  IF p_claim_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_CLAIM: Claim ID is required.';
  END IF;

  SELECT * INTO v_wallet
  FROM public.customer_wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  PERFORM private.release_expired_claim_reservations(p_user_id);

  SELECT * INTO v_claim
  FROM public.reward_claims
  WHERE id = p_claim_id
    AND user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'CLAIM_NOT_FOUND: Reward claim not found.';
  END IF;

  IF v_claim.status = 'pending' THEN
    UPDATE public.reward_claims
    SET
      status = 'cancelled',
      released_at = now(),
      updated_at = now()
    WHERE id = v_claim.id
    RETURNING * INTO v_claim;

    IF v_claim.qr_token_id IS NOT NULL THEN
      UPDATE public.customer_qr_tokens
      SET
        status = 'revoked',
        revoked_at = now(),
        allow_deduction = false
      WHERE id = v_claim.qr_token_id
        AND status = 'active';
    END IF;

    UPDATE public.customer_wallets
    SET
      available_points = available_points + v_claim.points,
      reserved_points = GREATEST(0, reserved_points - v_claim.points),
      updated_at = now()
    WHERE user_id = p_user_id
    RETURNING * INTO v_wallet;
  ELSE
    SELECT * INTO v_wallet
    FROM public.customer_wallets
    WHERE user_id = p_user_id;
  END IF;

  SELECT qr_payload INTO v_qr_payload
  FROM public.customer_qr_tokens
  WHERE id = v_claim.qr_token_id;

  RETURN private.serialize_reward_claim_response(v_claim, v_qr_payload, v_wallet);
END;
$$;

REVOKE ALL ON FUNCTION private.cancel_reward_claim_for_customer(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.cancel_reward_claim_for_customer(uuid, uuid) TO authenticated;

-- 8. Customer SECURITY INVOKER RPCs
CREATE OR REPLACE FUNCTION public.get_claim_rewards_context()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
  v_wallet public.customer_wallets;
  v_rate numeric(10,4);
  v_pending_claim record;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  IF NOT private.is_approved_customer() THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_APPROVED: Only approved customers can claim rewards.';
  END IF;

  v_wallet := private.ensure_wallet_and_unlock_allocations(v_uid);

  SELECT COALESCE(points_to_inr_rate, 0.1000)
  INTO v_rate
  FROM public.reward_settings
  WHERE singleton_key = 'global'
  LIMIT 1;

  v_rate := COALESCE(v_rate, 0.1000);

  SELECT
    c.id,
    c.user_id,
    c.qr_token_id,
    c.claim_reference,
    t.qr_payload,
    c.points,
    c.points_to_inr_rate,
    c.discount_amount,
    c.status,
    c.expires_at,
    c.created_at,
    c.redeemed_at,
    c.bill_number,
    c.branch_name,
    c.released_at
  INTO v_pending_claim
  FROM public.reward_claims c
  LEFT JOIN public.customer_qr_tokens t ON t.id = c.qr_token_id
  WHERE c.user_id = v_uid
    AND c.status = 'pending'
    AND c.expires_at > now()
  ORDER BY c.created_at DESC
  LIMIT 1;

  RETURN jsonb_build_object(
    'wallet', jsonb_build_object(
      'customer_code', v_wallet.customer_code,
      'membership_tier', v_wallet.membership_tier,
      'available_points', v_wallet.available_points,
      'reserved_points', v_wallet.reserved_points,
      'locked_points', v_wallet.locked_points,
      'points_to_inr_rate', v_rate
    ),
    'active_pending_claim', CASE
      WHEN v_pending_claim.id IS NOT NULL THEN
        jsonb_build_object(
          'id', v_pending_claim.id,
          'user_id', v_pending_claim.user_id,
          'qr_token_id', v_pending_claim.qr_token_id,
          'claim_reference', v_pending_claim.claim_reference,
          'qr_payload', v_pending_claim.qr_payload,
          'points', v_pending_claim.points,
          'points_to_inr_rate', v_pending_claim.points_to_inr_rate,
          'discount_amount', v_pending_claim.discount_amount,
          'status', v_pending_claim.status,
          'expires_at', v_pending_claim.expires_at,
          'created_at', v_pending_claim.created_at,
          'redeemed_at', v_pending_claim.redeemed_at,
          'bill_number', v_pending_claim.bill_number,
          'branch_name', v_pending_claim.branch_name,
          'released_at', v_pending_claim.released_at
        )
      ELSE NULL
    END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_claim_rewards_context() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_claim_rewards_context() TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.create_customer_reward_claim(
  p_points integer,
  p_idempotency_key text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  RETURN private.create_reward_claim_for_customer(v_uid, p_points, p_idempotency_key);
END;
$$;

REVOKE ALL ON FUNCTION public.create_customer_reward_claim(integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_customer_reward_claim(integer, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_customer_claim_status(
  p_claim_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
  v_wallet public.customer_wallets;
  v_claim public.reward_claims;
  v_qr_payload text;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  IF p_claim_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_CLAIM: Claim ID is required.';
  END IF;

  -- Ensures any newly expired claims immediately transition and release reserved points
  v_wallet := private.ensure_wallet_and_unlock_allocations(v_uid);

  SELECT * INTO v_claim
  FROM public.reward_claims
  WHERE id = p_claim_id
    AND user_id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'CLAIM_NOT_FOUND: Reward claim not found.';
  END IF;

  SELECT qr_payload INTO v_qr_payload
  FROM public.customer_qr_tokens
  WHERE id = v_claim.qr_token_id;

  RETURN private.serialize_reward_claim_response(v_claim, v_qr_payload, v_wallet);
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_claim_status(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_claim_status(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.cancel_customer_reward_claim(
  p_claim_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  RETURN private.cancel_reward_claim_for_customer(v_uid, p_claim_id);
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_customer_reward_claim(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_customer_reward_claim(uuid) TO authenticated, service_role;

-- 9. Update home dashboard RPC to expose reserved_points additively
CREATE OR REPLACE FUNCTION public.get_customer_home_dashboard(
  p_auto_checkin boolean DEFAULT true
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
  v_profile public.profiles;
  v_wallet public.customer_wallets;
  v_settings public.reward_settings;
  v_streak jsonb;
  v_next_allocation record;
  v_points_today integer := 0;
  v_transactions jsonb;
  v_allocations jsonb;
  v_cycle_date date;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_uid;

  IF NOT FOUND OR v_profile.approval_status <> 'approved' THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_APPROVED: Customer account is not approved.';
  END IF;

  v_wallet := private.ensure_wallet_and_unlock_allocations(v_uid);
  v_streak := private.process_daily_streak_for_customer(v_uid, p_auto_checkin);

  SELECT * INTO v_wallet
  FROM public.customer_wallets
  WHERE user_id = v_uid;

  SELECT * INTO v_settings
  FROM public.reward_settings
  WHERE singleton_key = 'global'
  LIMIT 1;

  SELECT id, source_type, points, description, locked_at, unlock_at
  INTO v_next_allocation
  FROM public.point_allocations
  WHERE user_id = v_uid
    AND status = 'locked'
  ORDER BY unlock_at ASC
  LIMIT 1;

  v_cycle_date := ((now() AT TIME ZONE 'Asia/Kolkata') - interval '6 hours')::date;
  SELECT COALESCE(SUM(points_delta), 0)
  INTO v_points_today
  FROM public.point_transactions
  WHERE user_id = v_uid
    AND points_delta > 0
    AND created_at >= ((v_cycle_date::timestamp + interval '6 hours') AT TIME ZONE 'Asia/Kolkata');

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', t.id,
        'transaction_type', t.transaction_type,
        'title', t.title,
        'description', t.description,
        'points_delta', t.points_delta,
        'is_locked_allocation', t.is_locked_allocation,
        'created_at', t.created_at
      )
      ORDER BY t.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_transactions
  FROM (
    SELECT *
    FROM public.point_transactions
    WHERE user_id = v_uid
    ORDER BY created_at DESC
    LIMIT 25
  ) t;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', a.id,
        'source_type', a.source_type,
        'points', a.points,
        'status', a.status,
        'description', a.description,
        'locked_at', a.locked_at,
        'unlock_at', a.unlock_at
      )
      ORDER BY a.unlock_at ASC
    ),
    '[]'::jsonb
  )
  INTO v_allocations
  FROM public.point_allocations a
  WHERE a.user_id = v_uid
    AND a.status = 'locked';

  RETURN jsonb_build_object(
    'profile', jsonb_build_object(
      'id', v_profile.id,
      'full_name', v_profile.full_name,
      'email', v_profile.email,
      'mobile_number', v_profile.mobile_number,
      'approval_status', v_profile.approval_status
    ),
    'wallet', jsonb_build_object(
      'customer_code', v_wallet.customer_code,
      'membership_tier', v_wallet.membership_tier,
      'available_points', v_wallet.available_points,
      'reserved_points', v_wallet.reserved_points,
      'locked_points', v_wallet.locked_points,
      'lifetime_earned_points', v_wallet.lifetime_earned_points,
      'lifetime_redeemed_points', v_wallet.lifetime_redeemed_points,
      'points_earned_today', v_points_today,
      'points_to_inr_rate', COALESCE(v_settings.points_to_inr_rate, 0.1000)
    ),
    'next_unlock_allocation', CASE
      WHEN v_next_allocation.id IS NOT NULL THEN
        jsonb_build_object(
          'id', v_next_allocation.id,
          'source_type', v_next_allocation.source_type,
          'points', v_next_allocation.points,
          'description', v_next_allocation.description,
          'locked_at', v_next_allocation.locked_at,
          'unlock_at', v_next_allocation.unlock_at
        )
      ELSE NULL
    END,
    'locked_allocations', v_allocations,
    'streak', v_streak,
    'recent_transactions', v_transactions
  );
END;
$$;

-- 10. Upgrade Admin POS verification & single-use redemption RPCs to honor claim reservations atomically
CREATE OR REPLACE FUNCTION public.verify_customer_qr_for_pos(
  p_qr_input text,
  p_mode text DEFAULT 'give_reward'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid;
  v_clean text;
  v_mode text;
  v_token public.customer_qr_tokens;
  v_profile public.profiles;
  v_wallet public.customer_wallets;
  v_rate numeric;
  v_claim public.reward_claims;
  v_effective_available integer;
BEGIN
  v_admin_id := (SELECT auth.uid());
  IF v_admin_id IS NULL OR NOT private.is_admin() THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Only authorized admins can verify POS QR codes.';
  END IF;

  v_clean := trim(COALESCE(p_qr_input, ''));
  IF v_clean = '' THEN
    RAISE EXCEPTION 'INVALID_QR: QR payload or token code is required.';
  END IF;

  IF v_clean ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'INVALID_QR: Raw customer IDs are not valid QR codes.';
  END IF;

  v_mode := lower(trim(COALESCE(p_mode, 'give_reward')));
  IF v_mode NOT IN ('give_reward', 'verify_claim') THEN
    v_mode := 'give_reward';
  END IF;

  SELECT * INTO v_token
  FROM public.customer_qr_tokens
  WHERE qr_payload = v_clean
     OR upper(token_code) = upper(v_clean)
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'INVALID_QR: QR code not recognized or does not exist.';
  END IF;

  -- Sync wallet & release any expired pending claims cleanly before checking status
  v_wallet := private.admin_sync_customer_wallet(v_token.user_id);

  -- Re-read token in case expiry cleanup just transitioned status
  SELECT * INTO v_token
  FROM public.customer_qr_tokens
  WHERE id = v_token.id;

  IF v_mode = 'give_reward' AND v_token.token_purpose <> 'accrual' THEN
    RAISE EXCEPTION 'WRONG_QR_MODE: This is a Claim QR. Switch to Verify Claim mode to redeem points.';
  END IF;

  IF v_mode = 'verify_claim' AND (v_token.token_purpose <> 'claim' OR NOT v_token.allow_deduction) THEN
    RAISE EXCEPTION 'WRONG_QR_MODE: Personal Member QR cannot be used for deduction. Ask customer for a Claim QR.';
  END IF;

  IF v_token.status = 'revoked' OR v_token.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'QR_REVOKED: This QR code was revoked or cancelled by the customer.';
  END IF;

  IF v_token.status = 'used' OR v_token.used_at IS NOT NULL THEN
    RAISE EXCEPTION 'QR_ALREADY_USED: This QR code has already been redeemed or processed.';
  END IF;

  IF v_token.status = 'expired' OR v_token.expires_at <= now() THEN
    UPDATE public.customer_qr_tokens
    SET status = 'expired', allow_deduction = false
    WHERE id = v_token.id AND status = 'active';
    RAISE EXCEPTION 'QR_EXPIRED: This QR code has expired. Ask customer to refresh their QR.';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_token.user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'CUSTOMER_NOT_FOUND: Customer profile not found.';
  END IF;

  IF v_profile.approval_status <> 'approved' THEN
    RAISE EXCEPTION 'CUSTOMER_NOT_APPROVED: Customer account is not approved (status: %).', v_profile.approval_status;
  END IF;

  SELECT COALESCE(points_to_inr_rate, 0.1000)
  INTO v_rate
  FROM public.reward_settings
  WHERE singleton_key = 'global'
  LIMIT 1;

  SELECT * INTO v_claim
  FROM public.reward_claims
  WHERE qr_token_id = v_token.id
  LIMIT 1;

  v_effective_available := v_wallet.available_points + CASE
    WHEN v_claim.id IS NOT NULL AND v_claim.status = 'pending' THEN v_claim.points
    ELSE 0
  END;

  RETURN jsonb_build_object(
    'customer_id', v_profile.id,
    'full_name', v_profile.full_name,
    'email', v_profile.email,
    'mobile_number', v_profile.mobile_number,
    'approval_status', v_profile.approval_status,
    'membership_id', v_wallet.customer_code,
    'membership_tier', v_wallet.membership_tier,
    'available_points', v_effective_available,
    'unreserved_available_points', v_wallet.available_points,
    'reserved_points', v_wallet.reserved_points,
    'locked_points', v_wallet.locked_points,
    'lifetime_earned_points', v_wallet.lifetime_earned_points,
    'lifetime_redeemed_points', v_wallet.lifetime_redeemed_points,
    'points_to_inr_rate', COALESCE(v_rate, 0.1000),
    'token_id', v_token.id,
    'token_code', v_token.token_code,
    'qr_payload', v_token.qr_payload,
    'token_purpose', v_token.token_purpose,
    'allow_deduction', v_token.allow_deduction,
    'token_expires_at', v_token.expires_at,
    'verification_method', 'qr',
    'claim_id', v_claim.id,
    'claim_reference', v_claim.claim_reference,
    'claim_points', v_claim.points,
    'claim_discount_amount', v_claim.discount_amount,
    'claim_status', v_claim.status
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.redeem_customer_claim_qr(
  p_token_id uuid,
  p_redeem_points integer,
  p_bill_number text DEFAULT ''::text,
  p_branch_name text DEFAULT 'Counter #1 POS'::text,
  p_idempotency_key text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid;
  v_admin_email text;
  v_points integer := COALESCE(p_redeem_points, 0);
  v_bill text;
  v_branch text;
  v_idem text;
  v_token_user_id uuid;
  v_token public.customer_qr_tokens;
  v_claim public.reward_claims;
  v_profile public.profiles;
  v_wallet public.customer_wallets;
  v_rate numeric;
  v_tx_id uuid;
BEGIN
  v_admin_id := (SELECT auth.uid());
  IF v_admin_id IS NULL OR NOT private.is_admin() THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Only authorized admins can verify and redeem claim QRs.';
  END IF;

  IF p_token_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_QR: Claim QR token ID is required.';
  END IF;

  IF v_points <= 0 OR v_points > 1000000 THEN
    RAISE EXCEPTION 'INVALID_AMOUNT: Redeem points must be between 1 and 1,000,000.';
  END IF;

  v_bill := trim(COALESCE(p_bill_number, ''));
  IF length(v_bill) < 2 OR length(v_bill) > 64 THEN
    RAISE EXCEPTION 'INVALID_BILL: Valid bill reference number is required.';
  END IF;

  v_branch := COALESCE(NULLIF(trim(COALESCE(p_branch_name, '')), ''), 'Counter #1 POS');
  v_idem := NULLIF(trim(COALESCE(p_idempotency_key, '')), '');

  IF v_idem IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.point_transactions WHERE idempotency_key = v_idem || ':claim'
  ) THEN
    RAISE EXCEPTION 'DUPLICATE_TRANSACTION: This claim redemption has already been processed.';
  END IF;

  SELECT user_id INTO v_token_user_id
  FROM public.customer_qr_tokens
  WHERE id = p_token_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'INVALID_QR: Claim QR token not found.';
  END IF;

  -- Lock & sync wallet first (deterministic lock ordering), releasing any expired reservations
  PERFORM private.admin_sync_customer_wallet(v_token_user_id);

  SELECT * INTO v_wallet
  FROM public.customer_wallets
  WHERE user_id = v_token_user_id
  FOR UPDATE;

  SELECT * INTO v_token
  FROM public.customer_qr_tokens
  WHERE id = p_token_id
  FOR UPDATE;

  SELECT * INTO v_claim
  FROM public.reward_claims
  WHERE qr_token_id = v_token.id
  FOR UPDATE;

  IF v_token.token_purpose <> 'claim' OR NOT v_token.allow_deduction THEN
    RAISE EXCEPTION 'WRONG_QR_MODE: Selected QR does not authorize point deduction.';
  END IF;

  IF v_token.status = 'used' OR v_token.used_at IS NOT NULL THEN
    RAISE EXCEPTION 'QR_ALREADY_USED: This Claim QR has already been redeemed.';
  END IF;

  IF v_token.status = 'revoked' OR v_token.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'QR_REVOKED: This Claim QR has been revoked or cancelled.';
  END IF;

  IF v_token.status = 'expired' OR v_token.expires_at <= now() THEN
    UPDATE public.customer_qr_tokens
    SET status = 'expired', allow_deduction = false
    WHERE id = v_token.id AND status = 'active';
    RAISE EXCEPTION 'QR_EXPIRED: Claim QR expired. Ask customer to generate a new Claim QR.';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_token.user_id;

  IF NOT FOUND OR v_profile.approval_status <> 'approved' THEN
    RAISE EXCEPTION 'CUSTOMER_NOT_APPROVED: Customer account is not approved.';
  END IF;

  IF v_claim.id IS NOT NULL THEN
    IF v_claim.status = 'redeemed' THEN
      RAISE EXCEPTION 'QR_ALREADY_USED: This claim has already been redeemed.';
    END IF;
    IF v_claim.status <> 'pending' THEN
      RAISE EXCEPTION 'INVALID_CLAIM_STATE: This claim is % and cannot be redeemed.', v_claim.status;
    END IF;
    IF v_claim.expires_at <= now() THEN
      RAISE EXCEPTION 'QR_EXPIRED: Claim QR expired. Reserved points have been returned to the customer.';
    END IF;
    IF v_points <> v_claim.points THEN
      RAISE EXCEPTION 'CLAIM_AMOUNT_MISMATCH: This Claim QR authorizes exactly % pts (₹%).', v_claim.points, v_claim.discount_amount;
    END IF;
    IF v_wallet.reserved_points < v_claim.points THEN
      RAISE EXCEPTION 'INSUFFICIENT_RESERVED_BALANCE: Reserved points for this claim are unavailable.';
    END IF;

    v_rate := v_claim.points_to_inr_rate;
  ELSE
    -- Backward-compatible path for generic claim tokens without a pre-allocated amount
    IF v_wallet.available_points < v_points THEN
      RAISE EXCEPTION 'INSUFFICIENT_BALANCE: Customer has % instant points available, requested %.', v_wallet.available_points, v_points;
    END IF;

    SELECT COALESCE(points_to_inr_rate, 0.1000)
    INTO v_rate
    FROM public.reward_settings
    WHERE singleton_key = 'global'
    LIMIT 1;
    v_rate := COALESCE(v_rate, 0.1000);
  END IF;

  v_admin_email := COALESCE((SELECT auth.jwt())->>'email', 'admin');

  UPDATE public.customer_qr_tokens
  SET
    status = 'used',
    used_at = now(),
    allow_deduction = false
  WHERE id = v_token.id;

  IF v_claim.id IS NOT NULL THEN
    -- Consume reservation without double-subtracting from available_points
    UPDATE public.customer_wallets
    SET
      reserved_points = reserved_points - v_claim.points,
      lifetime_redeemed_points = lifetime_redeemed_points + v_points,
      updated_at = now()
    WHERE user_id = v_profile.id
    RETURNING * INTO v_wallet;
  ELSE
    UPDATE public.customer_wallets
    SET
      available_points = available_points - v_points,
      lifetime_redeemed_points = lifetime_redeemed_points + v_points,
      updated_at = now()
    WHERE user_id = v_profile.id
    RETURNING * INTO v_wallet;
  END IF;

  INSERT INTO public.point_transactions (
    user_id,
    transaction_type,
    title,
    description,
    points_delta,
    is_locked_allocation,
    reference_id,
    idempotency_key,
    metadata
  ) VALUES (
    v_profile.id,
    'discount_redemption',
    'Claim Verified & Redeemed',
    'Redeemed ' || v_points || ' pts • Bill #' || v_bill,
    -v_points,
    false,
    COALESCE(v_claim.id, v_token.id),
    CASE WHEN v_idem IS NOT NULL THEN v_idem || ':claim' ELSE NULL END,
    jsonb_build_object(
      'admin_id', v_admin_id,
      'admin_email', v_admin_email,
      'bill_number', v_bill,
      'branch_name', v_branch,
      'qr_token_id', v_token.id,
      'token_code', v_token.token_code,
      'claim_id', v_claim.id,
      'claim_reference', v_claim.claim_reference,
      'rate', v_rate,
      'inr_equivalent', COALESCE(v_claim.discount_amount, round((v_points * v_rate)::numeric, 2)),
      'source', 'pos_scanner_claim'
    )
  )
  RETURNING id INTO v_tx_id;

  IF v_claim.id IS NOT NULL THEN
    UPDATE public.reward_claims
    SET
      status = 'redeemed',
      redeemed_at = now(),
      redeemed_by = v_admin_id,
      redeemed_by_email = v_admin_email,
      bill_number = v_bill,
      branch_name = v_branch,
      transaction_id = v_tx_id,
      updated_at = now()
    WHERE id = v_claim.id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'customer_id', v_profile.id,
    'full_name', v_profile.full_name,
    'membership_id', v_wallet.customer_code,
    'token_code', v_token.token_code,
    'claim_id', v_claim.id,
    'claim_reference', v_claim.claim_reference,
    'redeemed_points', v_points,
    'inr_value', COALESCE(v_claim.discount_amount, round((v_points * v_rate)::numeric, 2)),
    'bill_number', v_bill,
    'branch_name', v_branch,
    'available_points', v_wallet.available_points,
    'reserved_points', v_wallet.reserved_points,
    'locked_points', v_wallet.locked_points,
    'lifetime_redeemed_points', v_wallet.lifetime_redeemed_points,
    'transaction_id', v_tx_id,
    'redeemed_at', now()
  );
END;
$$;
