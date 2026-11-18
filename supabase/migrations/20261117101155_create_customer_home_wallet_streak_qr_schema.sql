-- Migration: create_customer_home_wallet_streak_qr_schema
-- Created for SHIIFTEX Customer Home Dashboard, Wallet, 7-Day Streak Lock/Unlock, and Single-Use Claim QR

-- 1. Customer Wallets Table
CREATE TABLE IF NOT EXISTS public.customer_wallets (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  customer_code text NOT NULL UNIQUE,
  membership_tier text NOT NULL DEFAULT 'Pebble Black Member',
  available_points integer NOT NULL DEFAULT 0 CHECK (available_points >= 0),
  locked_points integer NOT NULL DEFAULT 0 CHECK (locked_points >= 0),
  lifetime_earned_points integer NOT NULL DEFAULT 0 CHECK (lifetime_earned_points >= 0),
  lifetime_redeemed_points integer NOT NULL DEFAULT 0 CHECK (lifetime_redeemed_points >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_wallets FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.customer_wallets FROM PUBLIC, anon;
GRANT SELECT ON public.customer_wallets TO authenticated;

CREATE POLICY customer_wallets_select_own_or_admin
  ON public.customer_wallets
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id OR (SELECT private.is_admin()));

-- 2. Locked Point Allocations Table
CREATE TABLE IF NOT EXISTS public.point_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_type text NOT NULL CHECK (source_type IN ('daily_streak', 'merchant_settlement', 'campaign_bonus')),
  idempotency_key text UNIQUE,
  points integer NOT NULL CHECK (points > 0),
  status text NOT NULL DEFAULT 'locked' CHECK (status IN ('locked', 'unlocked', 'forfeited')),
  description text NOT NULL,
  locked_at timestamptz NOT NULL DEFAULT now(),
  unlock_at timestamptz NOT NULL,
  unlocked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS point_allocations_user_status_idx
  ON public.point_allocations(user_id, status, unlock_at);

ALTER TABLE public.point_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_allocations FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.point_allocations FROM PUBLIC, anon;
GRANT SELECT ON public.point_allocations TO authenticated;

CREATE POLICY point_allocations_select_own_or_admin
  ON public.point_allocations
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id OR (SELECT private.is_admin()));

-- 3. Point Transactions Table
CREATE TABLE IF NOT EXISTS public.point_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  transaction_type text NOT NULL CHECK (
    transaction_type IN (
      'daily_streak',
      'merchant_reward',
      'discount_redemption',
      'point_adjustment',
      'streak_unlock'
    )
  ),
  title text NOT NULL,
  description text NOT NULL,
  points_delta integer NOT NULL,
  is_locked_allocation boolean NOT NULL DEFAULT false,
  reference_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS point_transactions_user_created_idx
  ON public.point_transactions(user_id, created_at DESC);

ALTER TABLE public.point_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_transactions FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.point_transactions FROM PUBLIC, anon;
GRANT SELECT ON public.point_transactions TO authenticated;

CREATE POLICY point_transactions_select_own_or_admin
  ON public.point_transactions
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id OR (SELECT private.is_admin()));

-- 4. Customer Single-Use Claim QR Tokens Table
CREATE TABLE IF NOT EXISTS public.customer_qr_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token_code text NOT NULL UNIQUE,
  qr_payload text NOT NULL UNIQUE,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'used', 'expired')),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '5 minutes'),
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS customer_qr_tokens_user_status_idx
  ON public.customer_qr_tokens(user_id, status, expires_at DESC);

ALTER TABLE public.customer_qr_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_qr_tokens FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.customer_qr_tokens FROM PUBLIC, anon;
GRANT SELECT ON public.customer_qr_tokens TO authenticated;

CREATE POLICY customer_qr_tokens_select_own_or_admin
  ON public.customer_qr_tokens
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id OR (SELECT private.is_admin()));
