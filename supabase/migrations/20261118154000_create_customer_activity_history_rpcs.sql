-- Migration: create_customer_activity_history_rpcs
-- Adds indexes and SECURITY INVOKER RPCs for Customer Activity & History:
-- wallet summary with ledger reconciliation, filtered paginated feed with
-- split POS instant+future grouping, on-demand transaction audit details,
-- and monthly PDF/CSV statement aggregation.

CREATE INDEX IF NOT EXISTS reward_claims_user_created_idx
  ON public.reward_claims(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS reward_claims_transaction_idx
  ON public.reward_claims(transaction_id)
  WHERE transaction_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS point_allocations_user_created_idx
  ON public.point_allocations(user_id, created_at DESC);

-- Helper: resolve validated IANA timezone safely
CREATE OR REPLACE FUNCTION private.resolve_valid_timezone(p_timezone text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_candidate text := NULLIF(trim(COALESCE(p_timezone, '')), '');
  v_default text := 'Asia/Kolkata';
  v_valid text;
BEGIN
  SELECT COALESCE(NULLIF(trim(timezone), ''), 'Asia/Kolkata')
  INTO v_default
  FROM public.reward_settings
  WHERE singleton_key = 'global'
  LIMIT 1;

  IF v_candidate IS NULL THEN
    RETURN COALESCE(v_default, 'Asia/Kolkata');
  END IF;

  SELECT name
  INTO v_valid
  FROM pg_catalog.pg_timezone_names
  WHERE name = v_candidate
  LIMIT 1;

  RETURN COALESCE(v_valid, v_default, 'Asia/Kolkata');
END;
$$;

REVOKE ALL ON FUNCTION private.resolve_valid_timezone(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.resolve_valid_timezone(text) TO authenticated;

-- 1. Paginated Activity & History + Server-Side Wallet Summary & Reconciliation
CREATE OR REPLACE FUNCTION public.get_customer_activity_history(
  p_filter text DEFAULT 'all',
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0,
  p_timezone text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
  v_wallet public.customer_wallets;
  v_settings public.reward_settings;
  v_filter text := lower(trim(COALESCE(p_filter, 'all')));
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
  v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
  v_tz text;
  v_current_rate numeric(12,6) := 0.100000;
  v_current_pts_per_rupee integer := 10;
  v_currency_code text := 'INR';

  v_lifetime_earned_pts bigint := 0;
  v_lifetime_earned_inr numeric(14,2) := 0.00;
  v_total_redeemed_pts bigint := 0;
  v_total_redeemed_inr numeric(14,2) := 0.00;
  v_ledger_instant_credits bigint := 0;
  v_ledger_instant_debits bigint := 0;
  v_expected_available bigint := 0;
  v_expected_locked bigint := 0;
  v_avail_diff bigint := 0;
  v_locked_diff bigint := 0;
  v_has_discrepancy boolean := false;
  v_rows jsonb := '[]'::jsonb;
  v_has_more boolean := false;
  v_raw_count integer := 0;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  IF NOT private.is_approved_customer() THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_APPROVED: Only approved customers can view transaction history.';
  END IF;

  IF v_filter NOT IN ('all', 'earned', 'claims', 'daily_streak') THEN
    v_filter := 'all';
  END IF;

  -- Sync unlocks & release any expired claim reservations first
  v_wallet := private.ensure_wallet_and_unlock_allocations(v_uid);
  v_tz := private.resolve_valid_timezone(p_timezone);

  SELECT * INTO v_settings
  FROM public.reward_settings
  WHERE singleton_key = 'global'
  LIMIT 1;

  IF FOUND THEN
    v_current_pts_per_rupee := GREATEST(COALESCE(v_settings.points_per_rupee, 10), 1);
    v_current_rate := COALESCE(
      v_settings.points_to_inr_rate,
      ROUND((1::numeric / v_current_pts_per_rupee::numeric), 6)
    );
    v_currency_code := COALESCE(NULLIF(trim(v_settings.currency_code), ''), 'INR');
  END IF;

  -- Authoritative historical ledger aggregation:
  -- - Counts each valid earning transaction once (excludes streak_unlock transfer events,
  --   forfeited allocations, and incomplete in-progress Day 1..6 streak previews)
  -- - Preserves each transaction's historical cash_value / rate snapshot
  SELECT
    COALESCE(SUM(
      CASE
        WHEN t.points_delta > 0
          AND t.transaction_type <> 'streak_unlock'
          AND COALESCE((t.metadata->>'in_progress_streak')::boolean, false) = false
          AND COALESCE(pa.status, '') <> 'forfeited'
        THEN t.points_delta
        ELSE 0
      END
    ), 0)::bigint,
    COALESCE(ROUND(SUM(
      CASE
        WHEN t.points_delta > 0
          AND t.transaction_type <> 'streak_unlock'
          AND COALESCE((t.metadata->>'in_progress_streak')::boolean, false) = false
          AND COALESCE(pa.status, '') <> 'forfeited'
        THEN COALESCE(
          t.cash_value,
          NULLIF(t.metadata->>'inr_equivalent', '')::numeric,
          ROUND((t.points_delta * COALESCE(t.points_to_inr_rate, NULLIF(t.metadata->>'rate', '')::numeric, v_current_rate))::numeric, 2)
        )
        ELSE 0
      END
    )::numeric, 2), 0.00),
    COALESCE(SUM(
      CASE WHEN t.points_delta < 0 THEN ABS(t.points_delta) ELSE 0 END
    ), 0)::bigint,
    COALESCE(ROUND(SUM(
      CASE
        WHEN t.points_delta < 0 THEN
          COALESCE(
            t.cash_value,
            NULLIF(t.metadata->>'inr_equivalent', '')::numeric,
            ROUND((ABS(t.points_delta) * COALESCE(t.points_to_inr_rate, NULLIF(t.metadata->>'rate', '')::numeric, v_current_rate))::numeric, 2)
          )
        ELSE 0
      END
    )::numeric, 2), 0.00),
    COALESCE(SUM(
      CASE
        WHEN t.points_delta > 0 AND COALESCE(t.is_locked_allocation, false) = false
        THEN t.points_delta
        ELSE 0
      END
    ), 0)::bigint,
    COALESCE(SUM(
      CASE
        WHEN t.points_delta < 0 AND COALESCE(t.is_locked_allocation, false) = false
        THEN ABS(t.points_delta)
        ELSE 0
      END
    ), 0)::bigint
  INTO
    v_lifetime_earned_pts,
    v_lifetime_earned_inr,
    v_total_redeemed_pts,
    v_total_redeemed_inr,
    v_ledger_instant_credits,
    v_ledger_instant_debits
  FROM public.point_transactions t
  LEFT JOIN public.point_allocations pa
    ON pa.id = COALESCE(
      NULLIF(t.metadata->>'allocation_id', '')::uuid,
      CASE WHEN t.transaction_type IN ('daily_streak', 'streak_unlock') OR t.is_locked_allocation THEN t.reference_id ELSE NULL END
    )
    AND pa.user_id = v_uid
  WHERE t.user_id = v_uid;

  SELECT COALESCE(SUM(points), 0)::bigint
  INTO v_expected_locked
  FROM public.point_allocations
  WHERE user_id = v_uid
    AND status = 'locked';

  v_expected_available := GREATEST(0, v_ledger_instant_credits - v_ledger_instant_debits - v_wallet.reserved_points);
  v_avail_diff := v_wallet.available_points - (v_ledger_instant_credits - v_ledger_instant_debits - v_wallet.reserved_points);
  v_locked_diff := v_wallet.locked_points - v_expected_locked;
  v_has_discrepancy := (v_avail_diff <> 0 OR v_locked_diff <> 0);

  -- Build unified activity feed:
  -- Pairs split POS purchases (same bill instant + future locked row) cleanly,
  -- joins sanitized allocation/claim status, and appends cancelled/expired/rejected claim attempts on 'all'.
  WITH base_tx AS (
    SELECT
      t.id,
      t.user_id,
      t.transaction_type,
      t.title,
      t.description,
      t.points_delta,
      COALESCE(t.is_locked_allocation, false) AS is_locked_allocation,
      t.reference_id,
      t.idempotency_key,
      COALESCE(
        t.cash_value,
        NULLIF(t.metadata->>'inr_equivalent', '')::numeric,
        ROUND((ABS(t.points_delta) * COALESCE(t.points_to_inr_rate, NULLIF(t.metadata->>'rate', '')::numeric, v_current_rate))::numeric, 2)
      )::numeric(12,2) AS inr_value,
      COALESCE(
        t.points_to_inr_rate,
        NULLIF(t.metadata->>'rate', '')::numeric,
        v_current_rate
      )::numeric(12,6) AS historical_rate,
      COALESCE(
        t.points_per_rupee,
        ROUND(t.points_per_currency_unit)::integer,
        NULLIF(t.metadata->>'points_per_rupee', '')::integer,
        v_current_pts_per_rupee
      ) AS historical_pts_per_rupee,
      COALESCE(NULLIF(t.currency_code, ''), NULLIF(t.metadata->>'currency_code', ''), v_currency_code) AS currency_code,
      t.metadata,
      t.created_at,
      CASE
        WHEN t.transaction_type = 'merchant_reward' THEN
          'pos:' || COALESCE(
            NULLIF(regexp_replace(COALESCE(t.idempotency_key, ''), ':(instant|future)$', ''), ''),
            COALESCE(t.metadata->>'bill_number', '') || '|' || COALESCE(t.metadata->>'qr_token_id', '') || '|' || t.created_at::text
          )
        ELSE 'tx:' || t.id::text
      END AS group_key
    FROM public.point_transactions t
    WHERE t.user_id = v_uid
  ),
  grouped_tx AS (
    SELECT
      MIN(b.id::text)::uuid AS id,
      MAX(b.transaction_type) AS transaction_type,
      CASE
        WHEN MAX(b.transaction_type) = 'merchant_reward' AND COUNT(*) > 1 THEN
          COALESCE(NULLIF(trim(MAX(b.metadata->>'branch_name')), ''), 'POS Purchase Reward')
        ELSE
          MAX(b.title)
      END AS title,
      CASE
        WHEN MAX(b.transaction_type) = 'merchant_reward' AND COUNT(*) > 1 THEN
          'Purchase reward • Bill #' || COALESCE(NULLIF(trim(MAX(b.metadata->>'bill_number')), ''), 'POS')
        ELSE
          MAX(b.description)
      END AS description,
      SUM(b.points_delta)::integer AS points_delta,
      SUM(CASE WHEN b.points_delta > 0 AND NOT b.is_locked_allocation THEN b.points_delta ELSE 0 END)::integer AS available_points_part,
      SUM(CASE WHEN b.points_delta > 0 AND b.is_locked_allocation THEN b.points_delta ELSE 0 END)::integer AS locked_points_part,
      ROUND(SUM(b.inr_value)::numeric, 2) AS inr_value,
      MAX(b.historical_rate) AS historical_rate,
      MAX(b.historical_pts_per_rupee) AS historical_pts_per_rupee,
      MAX(b.currency_code) AS currency_code,
      bool_or(b.is_locked_allocation) AS has_locked_part,
      MAX(b.reference_id::text)::uuid AS reference_id,
      MAX(b.metadata->>'bill_number') AS bill_number,
      MAX(b.metadata->>'branch_name') AS branch_name,
      MAX(b.metadata->>'token_code') AS token_code,
      MAX(b.metadata->>'source') AS tx_source,
      MAX(b.metadata->>'unlock_at') AS unlock_at_raw,
      MAX(b.metadata->>'allocation_id') AS allocation_id_raw,
      MAX(b.metadata->>'streak_day') AS streak_day_raw,
      MAX(b.metadata->>'cycle_date') AS cycle_date,
      bool_or(COALESCE((b.metadata->>'in_progress_streak')::boolean, false)) AS is_in_progress_streak,
      MAX(b.metadata->>'campaign_name') AS campaign_name,
      MAX(b.metadata->>'campaign_code') AS campaign_code,
      MAX(b.metadata->>'campaign_validity') AS campaign_validity,
      MAX(b.metadata->>'adjustment_reason') AS adjustment_reason,
      MAX(b.metadata->>'purchase_amount') AS purchase_amount_raw,
      MAX(b.created_at) AS created_at
    FROM base_tx b
    GROUP BY b.group_key
  ),
  enriched_ledger AS (
    SELECT
      g.id::text AS entry_id,
      'ledger' AS record_source,
      CASE
        WHEN g.transaction_type = 'merchant_reward' THEN
          CASE WHEN COALESCE(g.tx_source, '') = 'campaign_bonus' THEN 'festival_bonus' ELSE 'pos_purchase' END
        WHEN g.transaction_type = 'discount_redemption' THEN 'claim_redemption'
        WHEN g.transaction_type = 'daily_streak' THEN 'daily_streak'
        WHEN g.transaction_type = 'streak_unlock' THEN 'locked_release'
        WHEN g.transaction_type = 'point_adjustment' THEN
          CASE
            WHEN COALESCE(g.tx_source, '') = 'registration_bonus' OR lower(g.title) LIKE '%registration%' THEN 'registration_bonus'
            WHEN COALESCE(g.tx_source, '') IN ('festival_bonus', 'campaign_bonus') OR lower(g.title) LIKE '%festival%' THEN 'festival_bonus'
            ELSE 'admin_adjustment'
          END
        ELSE 'admin_adjustment'
      END AS activity_kind,
      g.transaction_type,
      g.title,
      g.description,
      'TXN-' || UPPER(SUBSTR(REPLACE(g.id::text, '-', ''), 1, 6)) AS reference_code,
      g.points_delta,
      g.available_points_part,
      g.locked_points_part,
      g.inr_value,
      g.historical_rate,
      g.historical_pts_per_rupee,
      g.currency_code,
      CASE
        WHEN rc.id IS NOT NULL AND rc.audit_status IN ('rejected', 'flagged') THEN initcap(rc.audit_status)
        WHEN g.transaction_type = 'streak_unlock' THEN 'Released'
        WHEN g.is_in_progress_streak THEN 'In Progress'
        WHEN pa.status = 'forfeited' THEN 'Forfeited'
        WHEN pa.status = 'unlocked' THEN 'Unlocked'
        WHEN g.locked_points_part > 0 AND g.available_points_part > 0 THEN 'Partially Locked'
        WHEN g.locked_points_part > 0 THEN 'Locked'
        ELSE 'Completed'
      END AS status,
      g.created_at,
      jsonb_strip_nulls(jsonb_build_object(
        'merchant_name', COALESCE(rc.merchant_name, NULLIF(trim(g.branch_name), '')),
        'terminal_id', NULLIF(trim(g.branch_name), ''),
        'claim_voucher_code', COALESCE(rc.claim_reference, NULLIF(trim(g.token_code), '')),
        'reward_name', rc.reward_name,
        'order_reference', COALESCE(rc.order_reference, NULLIF(trim(g.bill_number), '')),
        'bill_number', NULLIF(trim(g.bill_number), ''),
        'purchase_amount', NULLIF(g.purchase_amount_raw, '')::numeric,
        'instant_points', g.available_points_part,
        'future_locked_points', g.locked_points_part,
        'unlock_at', COALESCE(pa.unlock_at::text, NULLIF(g.unlock_at_raw, '')),
        'unlocked_at', pa.unlocked_at::text,
        'allocation_status', pa.status,
        'streak_day', NULLIF(g.streak_day_raw, '')::integer,
        'cycle_reference', NULLIF(trim(g.cycle_date), ''),
        'in_progress_streak', g.is_in_progress_streak,
        'campaign_name', NULLIF(trim(g.campaign_name), ''),
        'campaign_code', NULLIF(trim(g.campaign_code), ''),
        'campaign_validity', NULLIF(trim(g.campaign_validity), ''),
        'adjustment_reason', COALESCE(NULLIF(trim(g.adjustment_reason), ''), CASE WHEN g.transaction_type = 'point_adjustment' THEN g.description ELSE NULL END),
        'audit_status', rc.audit_status,
        'redeemed_at', rc.redeemed_at::text,
        'audit_reference', COALESCE(rc.claim_reference, 'TXN-' || UPPER(SUBSTR(REPLACE(g.id::text, '-', ''), 1, 6))),
        'source', NULLIF(trim(g.tx_source), '')
      )) AS details,
      false AS is_failed_claim
    FROM grouped_tx g
    LEFT JOIN public.reward_claims rc
      ON (rc.transaction_id = g.id OR (g.reference_id IS NOT NULL AND (rc.id = g.reference_id OR rc.qr_token_id = g.reference_id)))
      AND rc.user_id = v_uid
    LEFT JOIN public.point_allocations pa
      ON pa.id = COALESCE(
        NULLIF(g.allocation_id_raw, '')::uuid,
        CASE WHEN g.transaction_type IN ('daily_streak', 'streak_unlock') OR g.has_locked_part THEN g.reference_id ELSE NULL END
      )
      AND pa.user_id = v_uid
  ),
  non_redeemed_claims AS (
    SELECT
      c.id::text AS entry_id,
      'claim_audit' AS record_source,
      'claim_redemption' AS activity_kind,
      'discount_redemption' AS transaction_type,
      COALESCE(NULLIF(trim(c.reward_name), ''), 'Claim Redemption') AS title,
      CASE
        WHEN c.audit_status = 'rejected' THEN COALESCE(NULLIF(trim(c.rejected_reason), ''), 'Claim rejected at counter')
        WHEN c.audit_status = 'flagged' THEN COALESCE(NULLIF(trim(c.flagged_reason), ''), 'Claim flagged during verification')
        WHEN c.status = 'expired' THEN 'Claim QR expired without scan (' || c.points || ' pts released)'
        ELSE COALESCE(NULLIF(trim(c.rejected_reason), ''), 'Claim cancelled (' || c.points || ' pts released)')
      END AS description,
      c.claim_reference AS reference_code,
      0::integer AS points_delta,
      0::integer AS available_points_part,
      0::integer AS locked_points_part,
      c.discount_amount AS inr_value,
      c.points_to_inr_rate::numeric(12,6) AS historical_rate,
      GREATEST(ROUND((1::numeric / c.points_to_inr_rate::numeric))::integer, 1) AS historical_pts_per_rupee,
      v_currency_code AS currency_code,
      CASE
        WHEN c.audit_status IN ('rejected', 'flagged') THEN initcap(c.audit_status)
        WHEN c.status = 'expired' THEN 'Expired'
        ELSE 'Cancelled'
      END AS status,
      COALESCE(c.released_at, c.updated_at, c.created_at) AS created_at,
      jsonb_strip_nulls(jsonb_build_object(
        'merchant_name', c.merchant_name,
        'terminal_id', c.branch_name,
        'claim_voucher_code', c.claim_reference,
        'reward_name', c.reward_name,
        'order_reference', c.order_reference,
        'bill_number', c.bill_number,
        'requested_points', c.points,
        'audit_status', c.audit_status,
        'rejected_reason', c.rejected_reason,
        'flagged_reason', c.flagged_reason,
        'audit_reference', c.claim_reference
      )) AS details,
      true AS is_failed_claim
    FROM public.reward_claims c
    WHERE c.user_id = v_uid
      AND c.transaction_id IS NULL
      AND c.status IN ('cancelled', 'expired')
  ),
  combined AS (
    SELECT * FROM enriched_ledger
    UNION ALL
    SELECT * FROM non_redeemed_claims
  ),
  filtered AS (
    SELECT *
    FROM combined c
    WHERE
      CASE v_filter
        WHEN 'earned' THEN
          NOT c.is_failed_claim
          AND c.points_delta > 0
          AND c.transaction_type <> 'streak_unlock'
        WHEN 'claims' THEN
          NOT c.is_failed_claim
          AND (c.transaction_type = 'discount_redemption' OR c.points_delta < 0)
        WHEN 'daily_streak' THEN
          c.transaction_type IN ('daily_streak', 'streak_unlock')
        ELSE true
      END
    ORDER BY c.created_at DESC, c.entry_id DESC
    LIMIT v_limit + 1
    OFFSET v_offset
  ),
  limited AS (
    SELECT * FROM filtered LIMIT v_limit
  )
  SELECT
    (SELECT COUNT(*)::integer FROM filtered),
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', l.entry_id,
            'record_source', l.record_source,
            'activity_kind', l.activity_kind,
            'transaction_type', l.transaction_type,
            'title', l.title,
            'description', l.description,
            'reference_code', l.reference_code,
            'points_delta', l.points_delta,
            'available_points_part', l.available_points_part,
            'locked_points_part', l.locked_points_part,
            'inr_value', l.inr_value,
            'historical_rate', l.historical_rate,
            'points_per_rupee', l.historical_pts_per_rupee,
            'currency_code', l.currency_code,
            'status', l.status,
            'created_at', l.created_at,
            'details', l.details
          )
          ORDER BY l.created_at DESC, l.entry_id DESC
        )
        FROM limited l
      ),
      '[]'::jsonb
    )
  INTO v_raw_count, v_rows;

  v_has_more := v_raw_count > v_limit;

  RETURN jsonb_build_object(
    'summary', jsonb_build_object(
      'customer_code', v_wallet.customer_code,
      'membership_tier', v_wallet.membership_tier,
      'net_available_points', v_wallet.available_points,
      'net_available_inr', ROUND((v_wallet.available_points * v_current_rate)::numeric, 2),
      'reserved_points', v_wallet.reserved_points,
      'locked_points', v_wallet.locked_points,
      'locked_inr', ROUND((v_wallet.locked_points * v_current_rate)::numeric, 2),
      'lifetime_earned_points', v_lifetime_earned_pts,
      'lifetime_earned_inr', v_lifetime_earned_inr,
      'total_redeemed_points', v_total_redeemed_pts,
      'total_redeemed_inr', v_total_redeemed_inr,
      'wallet_lifetime_earned_points', v_wallet.lifetime_earned_points,
      'current_points_to_inr_rate', v_current_rate,
      'current_points_per_rupee', v_current_pts_per_rupee,
      'currency_code', v_currency_code,
      'timezone', v_tz,
      'reconciliation', jsonb_build_object(
        'has_discrepancy', v_has_discrepancy,
        'available_offset_points', v_avail_diff,
        'locked_offset_points', v_locked_diff,
        'expected_available_from_ledger', v_ledger_instant_credits - v_ledger_instant_debits - v_wallet.reserved_points,
        'expected_locked_from_allocations', v_expected_locked
      )
    ),
    'filter', v_filter,
    'limit', v_limit,
    'offset', v_offset,
    'has_more', v_has_more,
    'transactions', v_rows
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_activity_history(text, integer, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_activity_history(text, integer, integer, text) TO authenticated, service_role;

-- 2. On-demand sanitized detail lookup when expanding a transaction card
CREATE OR REPLACE FUNCTION public.get_customer_transaction_detail(
  p_entry_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
  v_tx public.point_transactions;
  v_claim public.reward_claims;
  v_alloc public.point_allocations;
  v_paired_instant integer := 0;
  v_paired_locked integer := 0;
  v_paired_cash numeric(12,2) := 0.00;
  v_group_prefix text;
  v_rate numeric(12,6) := 0.100000;
  v_pts_per_rupee integer := 10;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  IF NOT private.is_approved_customer() THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_APPROVED: Only approved customers can inspect transaction details.';
  END IF;

  IF p_entry_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_ENTRY: Transaction ID is required.';
  END IF;

  SELECT * INTO v_tx
  FROM public.point_transactions
  WHERE id = p_entry_id
    AND user_id = v_uid;

  IF NOT FOUND THEN
    SELECT * INTO v_claim
    FROM public.reward_claims
    WHERE id = p_entry_id
      AND user_id = v_uid;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'TRANSACTION_NOT_FOUND: Transaction not found.';
    END IF;

    RETURN jsonb_build_object(
      'id', v_claim.id,
      'reference_code', v_claim.claim_reference,
      'status', CASE WHEN v_claim.audit_status IN ('rejected', 'flagged') THEN initcap(v_claim.audit_status) ELSE initcap(v_claim.status) END,
      'merchant_name', v_claim.merchant_name,
      'terminal_id', v_claim.branch_name,
      'claim_voucher_code', v_claim.claim_reference,
      'reward_name', v_claim.reward_name,
      'order_reference', v_claim.order_reference,
      'bill_number', v_claim.bill_number,
      'requested_points', v_claim.points,
      'historical_rate', v_claim.points_to_inr_rate,
      'points_per_rupee', GREATEST(ROUND((1::numeric / v_claim.points_to_inr_rate::numeric))::integer, 1),
      'inr_value', v_claim.discount_amount,
      'audit_status', v_claim.audit_status,
      'rejected_reason', v_claim.rejected_reason,
      'flagged_reason', v_claim.flagged_reason,
      'audit_reference', v_claim.claim_reference,
      'redeemed_at', v_claim.redeemed_at,
      'created_at', v_claim.created_at
    );
  END IF;

  v_rate := COALESCE(v_tx.points_to_inr_rate, NULLIF(v_tx.metadata->>'rate', '')::numeric, 0.100000);
  v_pts_per_rupee := COALESCE(v_tx.points_per_rupee, ROUND(v_tx.points_per_currency_unit)::integer, GREATEST(ROUND((1::numeric / v_rate))::integer, 1));

  IF v_tx.transaction_type = 'merchant_reward' THEN
    v_group_prefix := NULLIF(regexp_replace(COALESCE(v_tx.idempotency_key, ''), ':(instant|future)$', ''), '');
    SELECT
      COALESCE(SUM(CASE WHEN points_delta > 0 AND NOT COALESCE(is_locked_allocation, false) THEN points_delta ELSE 0 END), 0)::integer,
      COALESCE(SUM(CASE WHEN points_delta > 0 AND COALESCE(is_locked_allocation, false) THEN points_delta ELSE 0 END), 0)::integer,
      COALESCE(ROUND(SUM(COALESCE(cash_value, NULLIF(metadata->>'inr_equivalent', '')::numeric, ROUND((ABS(points_delta) * COALESCE(points_to_inr_rate, v_rate))::numeric, 2)))::numeric, 2), 0.00)
    INTO v_paired_instant, v_paired_locked, v_paired_cash
    FROM public.point_transactions
    WHERE user_id = v_uid
      AND transaction_type = 'merchant_reward'
      AND (
        (v_group_prefix IS NOT NULL AND regexp_replace(COALESCE(idempotency_key, ''), ':(instant|future)$', '') = v_group_prefix)
        OR (v_group_prefix IS NULL AND id = v_tx.id)
      );

    SELECT * INTO v_alloc
    FROM public.point_allocations
    WHERE user_id = v_uid
      AND id = COALESCE(
        NULLIF(v_tx.metadata->>'allocation_id', '')::uuid,
        v_tx.reference_id
      )
    LIMIT 1;
  ELSE
    v_paired_instant := CASE WHEN NOT COALESCE(v_tx.is_locked_allocation, false) THEN v_tx.points_delta ELSE 0 END;
    v_paired_locked := CASE WHEN COALESCE(v_tx.is_locked_allocation, false) THEN v_tx.points_delta ELSE 0 END;
    v_paired_cash := COALESCE(v_tx.cash_value, NULLIF(v_tx.metadata->>'inr_equivalent', '')::numeric, ROUND((ABS(v_tx.points_delta) * v_rate)::numeric, 2));
  END IF;

  SELECT * INTO v_claim
  FROM public.reward_claims
  WHERE user_id = v_uid
    AND (transaction_id = v_tx.id OR (v_tx.reference_id IS NOT NULL AND (id = v_tx.reference_id OR qr_token_id = v_tx.reference_id)))
  LIMIT 1;

  IF v_alloc.id IS NULL AND v_tx.reference_id IS NOT NULL AND (v_tx.transaction_type IN ('daily_streak', 'streak_unlock') OR COALESCE(v_tx.is_locked_allocation, false)) THEN
    SELECT * INTO v_alloc
    FROM public.point_allocations
    WHERE user_id = v_uid AND id = v_tx.reference_id
    LIMIT 1;
  END IF;

  RETURN jsonb_strip_nulls(jsonb_build_object(
    'id', v_tx.id,
    'reference_code', 'TXN-' || UPPER(SUBSTR(REPLACE(v_tx.id::text, '-', ''), 1, 6)),
    'merchant_name', COALESCE(v_claim.merchant_name, NULLIF(trim(v_tx.metadata->>'branch_name'), '')),
    'terminal_id', NULLIF(trim(v_tx.metadata->>'branch_name'), ''),
    'claim_voucher_code', COALESCE(v_claim.claim_reference, NULLIF(trim(v_tx.metadata->>'token_code'), '')),
    'reward_name', v_claim.reward_name,
    'order_reference', COALESCE(v_claim.order_reference, NULLIF(trim(v_tx.metadata->>'bill_number'), '')),
    'bill_number', NULLIF(trim(v_tx.metadata->>'bill_number'), ''),
    'purchase_amount', NULLIF(v_tx.metadata->>'purchase_amount', '')::numeric,
    'instant_points', v_paired_instant,
    'future_locked_points', v_paired_locked,
    'inr_value', v_paired_cash,
    'historical_rate', v_rate,
    'points_per_rupee', v_pts_per_rupee,
    'currency_code', COALESCE(v_tx.currency_code, 'INR'),
    'unlock_at', COALESCE(v_alloc.unlock_at::text, NULLIF(v_tx.metadata->>'unlock_at', '')),
    'unlocked_at', v_alloc.unlocked_at::text,
    'allocation_status', v_alloc.status,
    'streak_day', NULLIF(v_tx.metadata->>'streak_day', '')::integer,
    'cycle_reference', NULLIF(trim(v_tx.metadata->>'cycle_date'), ''),
    'campaign_name', NULLIF(trim(v_tx.metadata->>'campaign_name'), ''),
    'campaign_code', NULLIF(trim(v_tx.metadata->>'campaign_code'), ''),
    'campaign_validity', NULLIF(trim(v_tx.metadata->>'campaign_validity'), ''),
    'adjustment_reason', COALESCE(NULLIF(trim(v_tx.metadata->>'adjustment_reason'), ''), CASE WHEN v_tx.transaction_type = 'point_adjustment' THEN v_tx.description ELSE NULL END),
    'audit_status', v_claim.audit_status,
    'redeemed_at', v_claim.redeemed_at::text,
    'audit_reference', COALESCE(v_claim.claim_reference, 'TXN-' || UPPER(SUBSTR(REPLACE(v_tx.id::text, '-', ''), 1, 6))),
    'created_at', v_tx.created_at
  ));
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_transaction_detail(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_transaction_detail(uuid) TO authenticated, service_role;

-- 3. Monthly Statement RPC for accurate PDF / CSV generation
CREATE OR REPLACE FUNCTION public.get_customer_monthly_statement(
  p_year integer,
  p_month integer,
  p_timezone text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
  v_profile public.profiles;
  v_wallet public.customer_wallets;
  v_tz text;
  v_month_start timestamptz;
  v_month_end timestamptz;
  v_current_rate numeric(12,6) := 0.100000;
  v_net_after_month_end bigint := 0;
  v_net_during_month bigint := 0;
  v_opening_available bigint := 0;
  v_closing_available bigint := 0;
  v_total_earned bigint := 0;
  v_total_earned_inr numeric(14,2) := 0.00;
  v_total_redeemed bigint := 0;
  v_total_redeemed_inr numeric(14,2) := 0.00;
  v_locked_allocated bigint := 0;
  v_locked_released bigint := 0;
  v_items jsonb := '[]'::jsonb;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  IF NOT private.is_approved_customer() THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_APPROVED: Only approved customers can export statements.';
  END IF;

  IF p_year IS NULL OR p_year < 2020 OR p_year > 2100 OR p_month IS NULL OR p_month < 1 OR p_month > 12 THEN
    RAISE EXCEPTION 'INVALID_MONTH: Select a valid statement month and year.';
  END IF;

  v_wallet := private.ensure_wallet_and_unlock_allocations(v_uid);
  v_tz := private.resolve_valid_timezone(p_timezone);

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_uid;

  SELECT COALESCE(points_to_inr_rate, 0.100000)
  INTO v_current_rate
  FROM public.reward_settings
  WHERE singleton_key = 'global'
  LIMIT 1;

  v_month_start := pg_catalog.make_timestamptz(p_year, p_month, 1, 0, 0, 0, v_tz);
  v_month_end := v_month_start + interval '1 month';

  SELECT
    COALESCE(SUM(CASE WHEN created_at >= v_month_end AND NOT COALESCE(is_locked_allocation, false) THEN points_delta ELSE 0 END), 0)::bigint,
    COALESCE(SUM(CASE WHEN created_at >= v_month_start AND created_at < v_month_end AND NOT COALESCE(is_locked_allocation, false) THEN points_delta ELSE 0 END), 0)::bigint,
    COALESCE(SUM(CASE WHEN created_at >= v_month_start AND created_at < v_month_end AND points_delta > 0 AND transaction_type <> 'streak_unlock' AND COALESCE((metadata->>'in_progress_streak')::boolean, false) = false THEN points_delta ELSE 0 END), 0)::bigint,
    COALESCE(ROUND(SUM(CASE WHEN created_at >= v_month_start AND created_at < v_month_end AND points_delta > 0 AND transaction_type <> 'streak_unlock' AND COALESCE((metadata->>'in_progress_streak')::boolean, false) = false THEN COALESCE(cash_value, NULLIF(metadata->>'inr_equivalent', '')::numeric, ROUND((points_delta * COALESCE(points_to_inr_rate, v_current_rate))::numeric, 2)) ELSE 0 END)::numeric, 2), 0.00),
    COALESCE(SUM(CASE WHEN created_at >= v_month_start AND created_at < v_month_end AND points_delta < 0 THEN ABS(points_delta) ELSE 0 END), 0)::bigint,
    COALESCE(ROUND(SUM(CASE WHEN created_at >= v_month_start AND created_at < v_month_end AND points_delta < 0 THEN COALESCE(cash_value, NULLIF(metadata->>'inr_equivalent', '')::numeric, ROUND((ABS(points_delta) * COALESCE(points_to_inr_rate, v_current_rate))::numeric, 2)) ELSE 0 END)::numeric, 2), 0.00),
    COALESCE(SUM(CASE WHEN created_at >= v_month_start AND created_at < v_month_end AND transaction_type = 'streak_unlock' THEN points_delta ELSE 0 END), 0)::bigint
  INTO
    v_net_after_month_end,
    v_net_during_month,
    v_total_earned,
    v_total_earned_inr,
    v_total_redeemed,
    v_total_redeemed_inr,
    v_locked_released
  FROM public.point_transactions
  WHERE user_id = v_uid;

  SELECT COALESCE(SUM(points), 0)::bigint
  INTO v_locked_allocated
  FROM public.point_allocations
  WHERE user_id = v_uid
    AND locked_at >= v_month_start
    AND locked_at < v_month_end;

  v_closing_available := GREATEST(0, v_wallet.available_points - v_net_after_month_end);
  v_opening_available := GREATEST(0, v_closing_available - v_net_during_month);

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'transaction_id', 'TXN-' || UPPER(SUBSTR(REPLACE(t.id::text, '-', ''), 1, 6)),
        'raw_id', t.id,
        'transaction_type', t.transaction_type,
        'title', t.title,
        'description', t.description,
        'points_credited', CASE WHEN t.points_delta > 0 THEN t.points_delta ELSE 0 END,
        'points_deducted', CASE WHEN t.points_delta < 0 THEN ABS(t.points_delta) ELSE 0 END,
        'historical_inr', COALESCE(
          t.cash_value,
          NULLIF(t.metadata->>'inr_equivalent', '')::numeric,
          ROUND((ABS(t.points_delta) * COALESCE(t.points_to_inr_rate, NULLIF(t.metadata->>'rate', '')::numeric, v_current_rate))::numeric, 2)
        ),
        'historical_rate', COALESCE(t.points_to_inr_rate, NULLIF(t.metadata->>'rate', '')::numeric, v_current_rate),
        'currency_code', COALESCE(t.currency_code, 'INR'),
        'is_locked_allocation', COALESCE(t.is_locked_allocation, false),
        'status', CASE
          WHEN t.transaction_type = 'streak_unlock' THEN 'Released'
          WHEN COALESCE((t.metadata->>'in_progress_streak')::boolean, false) THEN 'In Progress'
          WHEN pa.status = 'unlocked' THEN 'Unlocked'
          WHEN pa.status = 'forfeited' THEN 'Forfeited'
          WHEN COALESCE(t.is_locked_allocation, false) THEN 'Locked'
          ELSE 'Completed'
        END,
        'created_at', t.created_at
      )
      ORDER BY t.created_at ASC, t.id ASC
    ),
    '[]'::jsonb
  )
  INTO v_items
  FROM public.point_transactions t
  LEFT JOIN public.point_allocations pa
    ON pa.id = COALESCE(
      NULLIF(t.metadata->>'allocation_id', '')::uuid,
      CASE WHEN t.transaction_type IN ('daily_streak', 'streak_unlock') OR COALESCE(t.is_locked_allocation, false) THEN t.reference_id ELSE NULL END
    )
    AND pa.user_id = v_uid
  WHERE t.user_id = v_uid
    AND t.created_at >= v_month_start
    AND t.created_at < v_month_end;

  RETURN jsonb_build_object(
    'customer_name', COALESCE(NULLIF(trim(v_profile.full_name), ''), 'SHIIFTEX Member'),
    'membership_id', v_wallet.customer_code,
    'year', p_year,
    'month', p_month,
    'timezone', v_tz,
    'opening_available_balance', v_opening_available,
    'total_earned_points', v_total_earned,
    'total_earned_inr', v_total_earned_inr,
    'total_redeemed_points', v_total_redeemed,
    'total_redeemed_inr', v_total_redeemed_inr,
    'locked_allocated_points', v_locked_allocated,
    'locked_released_points', v_locked_released,
    'closing_available_balance', v_closing_available,
    'generated_at', now(),
    'items', v_items
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_monthly_statement(integer, integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_monthly_statement(integer, integer, text) TO authenticated, service_role;
