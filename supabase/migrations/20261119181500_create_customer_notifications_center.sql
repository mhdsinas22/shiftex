-- Migration: create_customer_notifications_center
-- Implements In-App public.notifications table, strict customer RLS policies,
-- Supabase Realtime publication setup, automatic transactional triggers on POS
-- rewards, daily streak, locked point releases, claim lifecycle, active
-- advertisement campaigns (for eligible customers within campaign dates), and
-- account status transitions, plus paginated RPCs and mark-as-read operations.

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category text NOT NULL CHECK (
    category IN ('points_rewards', 'claims', 'announcements', 'account')
  ),
  notification_type text NOT NULL CHECK (
    notification_type IN (
      'pos_points_credited',
      'daily_streak_claimed',
      'streak_milestone_completed',
      'locked_points_released',
      'festival_bonus_credited',
      'admin_point_adjustment',
      'claim_generated',
      'claim_redeemed',
      'claim_expired',
      'claim_rejected',
      'campaign_published',
      'promotional_offer',
      'festival_announcement',
      'system_announcement',
      'account_approved',
      'account_status_changed'
    )
  ),
  title text NOT NULL,
  body text NOT NULL,
  points_amount integer DEFAULT NULL,
  cash_value numeric(12, 2) DEFAULT NULL,
  currency_code text NOT NULL DEFAULT 'INR',
  reference_type text DEFAULT NULL,
  reference_id uuid DEFAULT NULL,
  destination_route text DEFAULT NULL,
  badge_label text DEFAULT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  deduplication_key text DEFAULT NULL,
  read_at timestamp with time zone DEFAULT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id, created_at DESC)
  WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_user_category_created
  ON public.notifications (user_id, category, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS notifications_user_dedup_uidx
  ON public.notifications (user_id, deduplication_key)
  WHERE deduplication_key IS NOT NULL;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.notifications FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.notifications TO authenticated;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;

DROP POLICY IF EXISTS "Customers can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Customers can mark own notifications read" ON public.notifications;
DROP POLICY IF EXISTS "Admins can view all notifications" ON public.notifications;
DROP POLICY IF EXISTS "Customers and admins can view notifications" ON public.notifications;

CREATE POLICY "Customers and admins can view notifications"
  ON public.notifications
  FOR SELECT
  TO authenticated
  USING (((SELECT auth.uid()) = user_id) OR private.is_admin());

CREATE POLICY "Customers can mark own notifications read"
  ON public.notifications
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Enable Supabase Realtime Postgres Changes on notifications
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

-- Internal trigger helper: notify on committed point_transactions rows
CREATE OR REPLACE FUNCTION private.trg_notify_point_transaction()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_source text := lower(trim(COALESCE(NEW.metadata->>'source', '')));
  v_branch text := COALESCE(NULLIF(trim(NEW.metadata->>'branch_name'), ''), 'Partner POS');
  v_bill text := NULLIF(trim(NEW.metadata->>'bill_number'), '');
  v_base_idem text;
  v_dedup text;
  v_streak_day integer;
  v_days_left integer;
  v_cycle_date text := NULLIF(trim(NEW.metadata->>'cycle_date'), '');
  v_cash numeric(12, 2);
  v_rate numeric(12, 6);
  v_cash_text text;
  v_desc_prefix text;
  v_safe_meta jsonb;
BEGIN
  IF NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(points_to_inr_rate, 0.100000)
  INTO v_rate
  FROM public.reward_settings
  WHERE singleton_key = 'global'
  LIMIT 1;

  v_cash := COALESCE(
    NEW.cash_value,
    NULLIF(NEW.metadata->>'inr_equivalent', '')::numeric(12, 2),
    ROUND((ABS(NEW.points_delta) * COALESCE(NEW.points_to_inr_rate, v_rate, 0.100000))::numeric, 2)
  );
  v_cash_text := trim(to_char(COALESCE(v_cash, 0), 'FM999999990.00'));

  -- Strip admin PII before storing notification metadata
  v_safe_meta := COALESCE(NEW.metadata, '{}'::jsonb) - 'admin_id' - 'admin_email';

  -- 1. Festival / Campaign bonus points
  IF v_source IN ('festival_bonus', 'campaign_bonus')
     OR (NEW.transaction_type = 'point_adjustment' AND lower(COALESCE(NEW.title, '')) LIKE '%festival%') THEN
    v_dedup := 'tx:' || NEW.id::text;
    INSERT INTO public.notifications (
      user_id, category, notification_type, title, body,
      points_amount, cash_value, currency_code,
      reference_type, reference_id, destination_route, badge_label,
      metadata, deduplication_key
    ) VALUES (
      NEW.user_id,
      'points_rewards',
      'festival_bonus_credited',
      COALESCE(NULLIF(trim(NEW.title), ''), 'Festival Bonus Credited'),
      '+' || ABS(NEW.points_delta) || ' pts (≈ ₹' || v_cash_text || ') • ' || COALESCE(NULLIF(trim(NEW.description), ''), 'Promotional campaign bonus credited.'),
      NEW.points_delta,
      v_cash,
      COALESCE(NULLIF(trim(NEW.currency_code), ''), 'INR'),
      'point_transaction',
      NEW.id,
      '/activity-history',
      'Festive',
      v_safe_meta,
      v_dedup
    )
    ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
    RETURN NEW;
  END IF;

  -- 2. POS Merchant Purchase Rewards (supports combining split instant + future rows per bill)
  IF NEW.transaction_type = 'merchant_reward' AND NEW.points_delta > 0 THEN
    v_base_idem := COALESCE(
      NULLIF(regexp_replace(COALESCE(NEW.idempotency_key, ''), ':(instant|future)$', ''), ''),
      NULLIF(COALESCE(v_bill, '') || ':' || COALESCE(NEW.metadata->>'qr_token_id', ''), ':'),
      NEW.id::text
    );
    v_dedup := 'pos_reward:' || v_base_idem;

    INSERT INTO public.notifications (
      user_id, category, notification_type, title, body,
      points_amount, cash_value, currency_code,
      reference_type, reference_id, destination_route,
      metadata, deduplication_key
    ) VALUES (
      NEW.user_id,
      'points_rewards',
      'pos_points_credited',
      'Points Credited at ' || v_branch,
      '+' || NEW.points_delta || ' pts (≈ ₹' || v_cash_text || ') credited by ' || v_branch
        || CASE WHEN COALESCE(NEW.is_locked_allocation, false) THEN ' (Locked)' ELSE '' END
        || CASE WHEN v_bill IS NOT NULL THEN ' • Bill #' || v_bill ELSE '' END,
      NEW.points_delta,
      v_cash,
      COALESCE(NULLIF(trim(NEW.currency_code), ''), 'INR'),
      'point_transaction',
      NEW.id,
      '/activity-history',
      v_safe_meta || jsonb_build_object(
        'instant_points', CASE WHEN COALESCE(NEW.is_locked_allocation, false) THEN 0 ELSE NEW.points_delta END,
        'locked_points', CASE WHEN COALESCE(NEW.is_locked_allocation, false) THEN NEW.points_delta ELSE 0 END,
        'branch_name', v_branch,
        'bill_number', v_bill
      ),
      v_dedup
    )
    ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL
    DO UPDATE SET
      points_amount = COALESCE(public.notifications.points_amount, 0) + NEW.points_delta,
      cash_value = ROUND((COALESCE(public.notifications.cash_value, 0) + COALESCE(v_cash, 0))::numeric, 2),
      body = '+' || (COALESCE(public.notifications.points_amount, 0) + NEW.points_delta)
        || ' pts (≈ ₹'
        || trim(to_char(ROUND((COALESCE(public.notifications.cash_value, 0) + COALESCE(v_cash, 0))::numeric, 2), 'FM999999990.00'))
        || ') credited by ' || v_branch
        || CASE WHEN v_bill IS NOT NULL THEN ' • Bill #' || v_bill ELSE '' END,
      metadata = public.notifications.metadata || jsonb_build_object(
        'instant_points', COALESCE((public.notifications.metadata->>'instant_points')::integer, 0)
          + CASE WHEN COALESCE(NEW.is_locked_allocation, false) THEN 0 ELSE NEW.points_delta END,
        'locked_points', COALESCE((public.notifications.metadata->>'locked_points')::integer, 0)
          + CASE WHEN COALESCE(NEW.is_locked_allocation, false) THEN NEW.points_delta ELSE 0 END
      );
    RETURN NEW;
  END IF;

  -- 3. Daily Login Streak Check-ins & Day 7 Milestone
  IF NEW.transaction_type = 'daily_streak' AND NEW.points_delta > 0 THEN
    BEGIN
      v_streak_day := NULLIF(trim(NEW.metadata->>'streak_day'), '')::integer;
    EXCEPTION WHEN OTHERS THEN
      v_streak_day := NULL;
    END;

    v_dedup := CASE
      WHEN v_cycle_date IS NOT NULL AND v_streak_day IS NOT NULL
        THEN 'daily_streak:' || v_cycle_date || ':d' || v_streak_day::text
      ELSE 'tx:' || NEW.id::text
    END;

    IF COALESCE(v_streak_day, 0) = 7 THEN
      INSERT INTO public.notifications (
        user_id, category, notification_type, title, body,
        points_amount, cash_value, currency_code,
        reference_type, reference_id, destination_route,
        metadata, deduplication_key
      ) VALUES (
        NEW.user_id,
        'points_rewards',
        'streak_milestone_completed',
        '7-Day Streak Milestone Completed!',
        '+' || NEW.points_delta || ' pts earned across 7 consecutive days and scheduled for settlement unlock.',
        NEW.points_delta,
        v_cash,
        COALESCE(NULLIF(trim(NEW.currency_code), ''), 'INR'),
        'point_transaction',
        NEW.id,
        '/home',
        v_safe_meta || jsonb_build_object('scroll_target', 'streak'),
        v_dedup
      )
      ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
    ELSE
      v_days_left := GREATEST(0, 7 - COALESCE(v_streak_day, 1));
      INSERT INTO public.notifications (
        user_id, category, notification_type, title, body,
        points_amount, cash_value, currency_code,
        reference_type, reference_id, destination_route,
        metadata, deduplication_key
      ) VALUES (
        NEW.user_id,
        'points_rewards',
        'daily_streak_claimed',
        CASE
          WHEN v_streak_day IS NOT NULL THEN 'Daily Login Streak Day ' || v_streak_day || ' Claimed'
          ELSE 'Daily Login Streak Claimed'
        END,
        '+' || NEW.points_delta || ' pts added to your daily streak progress. '
          || v_days_left || CASE WHEN v_days_left = 1 THEN ' day' ELSE ' days' END || ' left to streak bonus!',
        NEW.points_delta,
        v_cash,
        COALESCE(NULLIF(trim(NEW.currency_code), ''), 'INR'),
        'point_transaction',
        NEW.id,
        '/home',
        v_safe_meta || jsonb_build_object('scroll_target', 'streak'),
        v_dedup
      )
      ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
    END IF;
    RETURN NEW;
  END IF;

  -- 4. Locked Points Settlement Release
  IF NEW.transaction_type = 'streak_unlock' AND NEW.points_delta > 0 THEN
    v_dedup := 'locked_release:' || COALESCE(NEW.reference_id::text, NEW.id::text);
    INSERT INTO public.notifications (
      user_id, category, notification_type, title, body,
      points_amount, cash_value, currency_code,
      reference_type, reference_id, destination_route,
      metadata, deduplication_key
    ) VALUES (
      NEW.user_id,
      'points_rewards',
      'locked_points_released',
      'Milestone Reward Unlocked!',
      'Your ' || NEW.points_delta || ' locked points have completed settlement clearance and are now available.',
      NEW.points_delta,
      v_cash,
      COALESCE(NULLIF(trim(NEW.currency_code), ''), 'INR'),
      'point_allocation',
      NEW.reference_id,
      '/home',
      v_safe_meta || jsonb_build_object('scroll_target', 'wallet'),
      v_dedup
    )
    ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
    RETURN NEW;
  END IF;

  -- 5. Admin Point Adjustments (or Registration Bonus)
  IF NEW.transaction_type = 'point_adjustment' THEN
    v_dedup := 'tx:' || NEW.id::text;
    v_desc_prefix := CASE WHEN NEW.points_delta >= 0 THEN '+' ELSE '' END || NEW.points_delta || ' pts';
    INSERT INTO public.notifications (
      user_id, category, notification_type, title, body,
      points_amount, cash_value, currency_code,
      reference_type, reference_id, destination_route,
      metadata, deduplication_key
    ) VALUES (
      NEW.user_id,
      'points_rewards',
      'admin_point_adjustment',
      COALESCE(NULLIF(trim(NEW.title), ''), 'Points Account Adjustment'),
      v_desc_prefix || ' (≈ ₹' || v_cash_text || ') • ' || COALESCE(NULLIF(trim(NEW.description), ''), 'Updated by SHIIFTEX administrator.'),
      NEW.points_delta,
      v_cash,
      COALESCE(NULLIF(trim(NEW.currency_code), ''), 'INR'),
      'point_transaction',
      NEW.id,
      '/activity-history',
      v_safe_meta,
      v_dedup
    )
    ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
    RETURN NEW;
  END IF;

  -- 6. Walk-in Claim Redemption fallback if no reward_claims row existed
  IF NEW.transaction_type = 'discount_redemption' AND NEW.points_delta < 0 THEN
    v_dedup := 'claim_redeemed:' || COALESCE(NEW.reference_id::text, NEW.id::text);
    INSERT INTO public.notifications (
      user_id, category, notification_type, title, body,
      points_amount, cash_value, currency_code,
      reference_type, reference_id, destination_route,
      metadata, deduplication_key
    ) VALUES (
      NEW.user_id,
      'claims',
      'claim_redeemed',
      'Claim Reward Redeemed',
      ABS(NEW.points_delta) || ' pts redeemed for ₹' || v_cash_text || ' cashier discount at ' || v_branch
        || COALESCE(' (' || NULLIF(trim(NEW.metadata->>'token_code'), '') || ')', '') || '.',
      NEW.points_delta,
      v_cash,
      COALESCE(NULLIF(trim(NEW.currency_code), ''), 'INR'),
      'reward_claim',
      NEW.reference_id,
      '/activity-history',
      v_safe_meta,
      v_dedup
    )
    ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_point_transaction ON public.point_transactions;
CREATE TRIGGER trg_notify_point_transaction
  AFTER INSERT ON public.point_transactions
  FOR EACH ROW
  EXECUTE FUNCTION private.trg_notify_point_transaction();

-- Internal trigger helper: notify on reward_claims lifecycle changes
CREATE OR REPLACE FUNCTION private.trg_notify_reward_claim()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_merchant text := COALESCE(NULLIF(trim(NEW.merchant_name), ''), NULLIF(trim(NEW.branch_name), ''), 'Partner Counter');
  v_reward text := COALESCE(NULLIF(trim(NEW.reward_name), ''), 'Instant POS Bill Discount');
  v_discount_text text := trim(to_char(COALESCE(NEW.discount_amount, 0), 'FM999999990.00'));
  v_reason text;
  v_dedup text;
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    v_dedup := 'claim_generated:' || NEW.id::text;
    INSERT INTO public.notifications (
      user_id, category, notification_type, title, body,
      points_amount, cash_value, currency_code,
      reference_type, reference_id, destination_route,
      metadata, deduplication_key
    ) VALUES (
      NEW.user_id,
      'claims',
      'claim_generated',
      'Claim QR Ready',
      NEW.points || ' pts (≈ ₹' || v_discount_text || ') reserved for ' || v_reward || '. Ref: ' || NEW.claim_reference || '.',
      NEW.points,
      NEW.discount_amount,
      'INR',
      'reward_claim',
      NEW.id,
      '/activity-history',
      jsonb_build_object(
        'claim_id', NEW.id,
        'claim_reference', NEW.claim_reference,
        'reward_name', v_reward,
        'merchant_name', v_merchant,
        'points', NEW.points,
        'discount_amount', NEW.discount_amount
      ),
      v_dedup
    )
    ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.status = 'redeemed' THEN
      v_dedup := 'claim_redeemed:' || COALESCE(NEW.qr_token_id::text, NEW.id::text);
      INSERT INTO public.notifications (
        user_id, category, notification_type, title, body,
        points_amount, cash_value, currency_code,
        reference_type, reference_id, destination_route,
        metadata, deduplication_key
      ) VALUES (
        NEW.user_id,
        'claims',
        'claim_redeemed',
        'Claim Reward Redeemed',
        NEW.points || ' pts redeemed for ₹' || v_discount_text || ' (' || v_reward || ') at ' || v_merchant || '. Ref: ' || NEW.claim_reference || '.',
        -NEW.points,
        NEW.discount_amount,
        'INR',
        'reward_claim',
        NEW.id,
        '/activity-history',
        jsonb_build_object(
          'claim_id', NEW.id,
          'claim_reference', NEW.claim_reference,
          'reward_name', v_reward,
          'merchant_name', v_merchant,
          'branch_name', NEW.branch_name,
          'bill_number', NEW.bill_number,
          'points', NEW.points,
          'discount_amount', NEW.discount_amount
        ),
        v_dedup
      )
      ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL
      DO UPDATE SET
        title = EXCLUDED.title,
        body = EXCLUDED.body,
        metadata = EXCLUDED.metadata;
    ELSIF NEW.status = 'expired' THEN
      v_dedup := 'claim_expired:' || NEW.id::text;
      INSERT INTO public.notifications (
        user_id, category, notification_type, title, body,
        points_amount, cash_value, currency_code,
        reference_type, reference_id, destination_route,
        metadata, deduplication_key
      ) VALUES (
        NEW.user_id,
        'claims',
        'claim_expired',
        'Claim QR Expired',
        'Dynamic QR ' || NEW.claim_reference || ' expired. ' || NEW.points || ' reserved pts were returned to your available balance.',
        NEW.points,
        NEW.discount_amount,
        'INR',
        'reward_claim',
        NEW.id,
        '/home',
        jsonb_build_object(
          'claim_id', NEW.id,
          'claim_reference', NEW.claim_reference,
          'points', NEW.points,
          'scroll_target', 'wallet'
        ),
        v_dedup
      )
      ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
    ELSIF NEW.status = 'cancelled' AND COALESCE(NEW.audit_status, '') IN ('rejected', 'flagged') THEN
      v_dedup := 'claim_rejected:' || NEW.id::text;
      v_reason := COALESCE(NULLIF(trim(NEW.rejected_reason), ''), NULLIF(trim(NEW.flagged_reason), ''), 'Verification declined at counter');
      INSERT INTO public.notifications (
        user_id, category, notification_type, title, body,
        points_amount, cash_value, currency_code,
        reference_type, reference_id, destination_route,
        metadata, deduplication_key
      ) VALUES (
        NEW.user_id,
        'claims',
        'claim_rejected',
        CASE WHEN NEW.audit_status = 'flagged' THEN 'Claim Flagged at POS' ELSE 'Claim Rejected' END,
        'Claim ' || NEW.claim_reference || ' (' || NEW.points || ' pts) at ' || v_merchant || ': ' || v_reason || '. Reserved pts released.',
        NEW.points,
        NEW.discount_amount,
        'INR',
        'reward_claim',
        NEW.id,
        '/activity-history',
        jsonb_build_object(
          'claim_id', NEW.id,
          'claim_reference', NEW.claim_reference,
          'audit_status', NEW.audit_status,
          'reason', v_reason
        ),
        v_dedup
      )
      ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_reward_claim ON public.reward_claims;
CREATE TRIGGER trg_notify_reward_claim
  AFTER INSERT OR UPDATE OF status ON public.reward_claims
  FOR EACH ROW
  EXECUTE FUNCTION private.trg_notify_reward_claim();

-- Internal trigger helper: notify customer when Admin approves/rejects/suspends account
CREATE OR REPLACE FUNCTION private.trg_notify_profile_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_dedup text;
BEGIN
  IF OLD.approval_status IS NOT DISTINCT FROM NEW.approval_status THEN
    RETURN NEW;
  END IF;

  IF NEW.approval_status = 'approved' THEN
    v_dedup := 'account_approved:' || NEW.id::text || ':' || extract(epoch FROM COALESCE(NEW.approved_at, now()))::bigint::text;
    INSERT INTO public.notifications (
      user_id, category, notification_type, title, body,
      reference_type, reference_id, destination_route,
      metadata, deduplication_key
    ) VALUES (
      NEW.id,
      'account',
      'account_approved',
      'Account Approved!',
      'Welcome to SHIIFTEX! Your customer profile is approved and your rewards wallet is ready.',
      'profile',
      NEW.id,
      '/home',
      jsonb_build_object('approval_status', NEW.approval_status),
      v_dedup
    )
    ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;

    INSERT INTO public.notifications (
      user_id, category, notification_type, title, body,
      reference_type, reference_id, destination_route, badge_label,
      metadata, deduplication_key, created_at
    )
    SELECT
      NEW.id,
      'announcements',
      CASE
        WHEN lower(COALESCE(a.title, '') || ' ' || COALESCE(a.offer_details, ''))
          ~ '(festival|festive|diwali|holi|eid|onam|pongal|christmas|halloween|new year|mahotsav)'
          THEN 'festival_announcement'
        ELSE 'campaign_published'
      END,
      a.title,
      COALESCE(
        NULLIF(trim(COALESCE(a.offer_details, '')), ''),
        'New exclusive campaign live through ' || to_char((a.end_at AT TIME ZONE 'Asia/Kolkata'), 'DD Mon YYYY') || '.'
      ),
      'advertisement',
      a.id,
      '/home',
      CASE
        WHEN lower(COALESCE(a.title, '') || ' ' || COALESCE(a.offer_details, ''))
          ~ '(festival|festive|diwali|holi|eid|onam|pongal|christmas|halloween|new year|mahotsav)'
          THEN 'Festive'
        ELSE 'Promo'
      END,
      jsonb_strip_nulls(jsonb_build_object(
        'advertisement_id', a.id,
        'title', a.title,
        'offer_details', a.offer_details,
        'image_url', a.image_url,
        'start_at', a.start_at,
        'end_at', a.end_at
      )),
      'ad_campaign:' || a.id::text,
      GREATEST(a.start_at, COALESCE(a.published_at, a.created_at))
    FROM public.advertisements a
    WHERE a.status = 'published'
      AND a.deactivated_at IS NULL
      AND a.start_at <= now()
      AND a.end_at >= now()
      AND NOT EXISTS (
        SELECT 1 FROM public.admin_users au
        WHERE au.user_id = NEW.id AND au.status = 'active'
      )
    ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
  ELSIF NEW.approval_status IN ('rejected', 'suspended') THEN
    v_dedup := 'account_status:' || NEW.id::text || ':' || NEW.approval_status || ':' || extract(epoch FROM COALESCE(NEW.updated_at, now()))::bigint::text;
    INSERT INTO public.notifications (
      user_id, category, notification_type, title, body,
      reference_type, reference_id, destination_route,
      metadata, deduplication_key
    ) VALUES (
      NEW.id,
      'account',
      'account_status_changed',
      CASE
        WHEN NEW.approval_status = 'suspended' THEN 'Account Suspended'
        ELSE 'Account Status Updated'
      END,
      CASE
        WHEN NULLIF(trim(COALESCE(NEW.rejection_reason, '')), '') IS NOT NULL
          THEN trim(NEW.rejection_reason)
        WHEN NEW.approval_status = 'suspended'
          THEN 'Your SHIIFTEX account access has been temporarily suspended by an administrator.'
        ELSE 'Your SHIIFTEX account application status changed to rejected.'
      END,
      'profile',
      NEW.id,
      '/pending-approval',
      jsonb_build_object(
        'approval_status', NEW.approval_status,
        'reason', NEW.rejection_reason
      ),
      v_dedup
    )
    ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_profile_status ON public.profiles;
CREATE TRIGGER trg_notify_profile_status
  AFTER UPDATE OF approval_status ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION private.trg_notify_profile_status();

-- Internal trigger helper: notify approved customers when Admin publishes active campaign
CREATE OR REPLACE FUNCTION private.trg_notify_published_advertisement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_is_festive boolean;
  v_notif_type text;
  v_badge text;
  v_body text;
BEGIN
  IF NEW.status <> 'published'
     OR NEW.deactivated_at IS NOT NULL
     OR NEW.start_at > now()
     OR NEW.end_at < now() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.status = 'published'
     AND OLD.deactivated_at IS NULL
     AND OLD.start_at <= now()
     AND OLD.end_at >= now() THEN
    RETURN NEW;
  END IF;

  v_is_festive := lower(COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.offer_details, ''))
    ~ '(festival|festive|diwali|holi|eid|onam|pongal|christmas|halloween|new year|mahotsav)';
  v_notif_type := CASE WHEN v_is_festive THEN 'festival_announcement' ELSE 'campaign_published' END;
  v_badge := CASE WHEN v_is_festive THEN 'Festive' ELSE 'Promo' END;
  v_body := COALESCE(
    NULLIF(trim(COALESCE(NEW.offer_details, '')), ''),
    'New exclusive campaign live through ' || to_char((NEW.end_at AT TIME ZONE 'Asia/Kolkata'), 'DD Mon YYYY') || '.'
  );

  INSERT INTO public.notifications (
    user_id, category, notification_type, title, body,
    reference_type, reference_id, destination_route, badge_label,
    metadata, deduplication_key
  )
  SELECT
    p.id,
    'announcements',
    v_notif_type,
    NEW.title,
    v_body,
    'advertisement',
    NEW.id,
    '/home',
    v_badge,
    jsonb_strip_nulls(jsonb_build_object(
      'advertisement_id', NEW.id,
      'title', NEW.title,
      'offer_details', NEW.offer_details,
      'image_url', NEW.image_url,
      'start_at', NEW.start_at,
      'end_at', NEW.end_at
    )),
    'ad_campaign:' || NEW.id::text
  FROM public.profiles p
  WHERE p.approval_status = 'approved'
    AND NOT EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE au.user_id = p.id AND au.status = 'active'
    )
  ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_published_advertisement ON public.advertisements;
CREATE TRIGGER trg_notify_published_advertisement
  AFTER INSERT OR UPDATE OF status, deactivated_at, start_at, end_at ON public.advertisements
  FOR EACH ROW
  EXECUTE FUNCTION private.trg_notify_published_advertisement();

-- 1. Paginated customer notifications feed + tab counts (SECURITY INVOKER)
CREATE OR REPLACE FUNCTION public.get_customer_notifications(
  p_filter text DEFAULT 'all',
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_filter text := lower(trim(COALESCE(p_filter, 'all')));
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
  v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
  v_total_count bigint := 0;
  v_unread_count bigint := 0;
  v_points_count bigint := 0;
  v_announcements_count bigint := 0;
  v_raw_count integer := 0;
  v_rows jsonb := '[]'::jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  IF v_filter NOT IN ('all', 'unread', 'points_rewards', 'announcements') THEN
    v_filter := 'all';
  END IF;

  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE n.read_at IS NULL)::bigint,
    COUNT(*) FILTER (WHERE n.category = 'points_rewards')::bigint,
    COUNT(*) FILTER (WHERE n.category = 'announcements')::bigint
  INTO
    v_total_count,
    v_unread_count,
    v_points_count,
    v_announcements_count
  FROM public.notifications n
  WHERE n.user_id = v_uid;

  WITH filtered AS (
    SELECT
      n.id,
      n.user_id,
      n.category,
      n.notification_type,
      n.title,
      n.body,
      n.points_amount,
      n.cash_value,
      n.currency_code,
      n.reference_type,
      n.reference_id,
      n.destination_route,
      n.badge_label,
      n.metadata,
      n.read_at,
      n.created_at
    FROM public.notifications n
    WHERE n.user_id = v_uid
      AND (
        CASE v_filter
          WHEN 'unread' THEN n.read_at IS NULL
          WHEN 'points_rewards' THEN n.category = 'points_rewards'
          WHEN 'announcements' THEN n.category = 'announcements'
          ELSE true
        END
      )
    ORDER BY n.created_at DESC, n.id DESC
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
            'id', l.id,
            'user_id', l.user_id,
            'category', l.category,
            'notification_type', l.notification_type,
            'title', l.title,
            'body', l.body,
            'points_amount', l.points_amount,
            'cash_value', l.cash_value,
            'currency_code', l.currency_code,
            'reference_type', l.reference_type,
            'reference_id', l.reference_id,
            'destination_route', l.destination_route,
            'badge_label', l.badge_label,
            'metadata', l.metadata,
            'read_at', l.read_at,
            'created_at', l.created_at
          )
          ORDER BY l.created_at DESC, l.id DESC
        )
        FROM limited l
      ),
      '[]'::jsonb
    )
  INTO v_raw_count, v_rows;

  RETURN jsonb_build_object(
    'filter', v_filter,
    'limit', v_limit,
    'offset', v_offset,
    'has_more', (v_raw_count > v_limit),
    'counts', jsonb_build_object(
      'all', v_total_count,
      'unread', v_unread_count,
      'points_rewards', v_points_count,
      'announcements', v_announcements_count
    ),
    'notifications', v_rows
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_customer_notifications(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_customer_notifications(text, integer, integer) TO authenticated;

-- 2. Mark individual notification as read securely for owner only
CREATE OR REPLACE FUNCTION public.mark_notification_as_read(
  p_notification_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_notif public.notifications;
  v_unread bigint := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  IF p_notification_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_NOTIFICATION: Notification ID is required.';
  END IF;

  UPDATE public.notifications
  SET read_at = COALESCE(read_at, now())
  WHERE id = p_notification_id
    AND user_id = v_uid
  RETURNING * INTO v_notif;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOTIFICATION_NOT_FOUND: Notification could not be found.';
  END IF;

  SELECT COUNT(*)::bigint
  INTO v_unread
  FROM public.notifications
  WHERE user_id = v_uid
    AND read_at IS NULL;

  RETURN jsonb_build_object(
    'id', v_notif.id,
    'read_at', v_notif.read_at,
    'unread_count', v_unread
  );
END;
$$;

REVOKE ALL ON FUNCTION public.mark_notification_as_read(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_notification_as_read(uuid) TO authenticated;

-- 3. Mark all unread notifications for the authenticated customer as read
CREATE OR REPLACE FUNCTION public.mark_all_notifications_as_read()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_now timestamp with time zone := now();
  v_updated_count integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  UPDATE public.notifications
  SET read_at = v_now
  WHERE user_id = v_uid
    AND read_at IS NULL;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'updated_count', v_updated_count,
    'unread_count', 0,
    'read_at', v_now
  );
END;
$$;

REVOKE ALL ON FUNCTION public.mark_all_notifications_as_read() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_as_read() TO authenticated;

-- 4. Fast unread count query for notification bell badge
CREATE OR REPLACE FUNCTION public.get_unread_notification_count()
RETURNS bigint
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_count bigint := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  SELECT COUNT(*)::bigint
  INTO v_count
  FROM public.notifications
  WHERE user_id = v_uid
    AND read_at IS NULL;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.get_unread_notification_count() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_unread_notification_count() TO authenticated;

-- 5. Idempotently materialize active scheduled/published campaigns for the signed-in approved customer
CREATE OR REPLACE FUNCTION public.sync_active_campaign_notifications()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_approved boolean := false;
  v_inserted integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = v_uid
      AND p.approval_status = 'approved'
      AND NOT EXISTS (
        SELECT 1 FROM public.admin_users au
        WHERE au.user_id = p.id AND au.status = 'active'
      )
  )
  INTO v_approved;

  IF NOT v_approved THEN
    RETURN 0;
  END IF;

  INSERT INTO public.notifications (
    user_id, category, notification_type, title, body,
    reference_type, reference_id, destination_route, badge_label,
    metadata, deduplication_key, created_at
  )
  SELECT
    v_uid,
    'announcements',
    CASE
      WHEN lower(COALESCE(a.title, '') || ' ' || COALESCE(a.offer_details, ''))
        ~ '(festival|festive|diwali|holi|eid|onam|pongal|christmas|halloween|new year|mahotsav)'
        THEN 'festival_announcement'
      ELSE 'campaign_published'
    END,
    a.title,
    COALESCE(
      NULLIF(trim(COALESCE(a.offer_details, '')), ''),
      'New exclusive campaign live through ' || to_char((a.end_at AT TIME ZONE 'Asia/Kolkata'), 'DD Mon YYYY') || '.'
    ),
    'advertisement',
    a.id,
    '/home',
    CASE
      WHEN lower(COALESCE(a.title, '') || ' ' || COALESCE(a.offer_details, ''))
        ~ '(festival|festive|diwali|holi|eid|onam|pongal|christmas|halloween|new year|mahotsav)'
        THEN 'Festive'
      ELSE 'Promo'
    END,
    jsonb_strip_nulls(jsonb_build_object(
      'advertisement_id', a.id,
      'title', a.title,
      'offer_details', a.offer_details,
      'image_url', a.image_url,
      'start_at', a.start_at,
      'end_at', a.end_at
    )),
    'ad_campaign:' || a.id::text,
    GREATEST(a.start_at, COALESCE(a.published_at, a.created_at))
  FROM public.advertisements a
  WHERE a.status = 'published'
    AND a.deactivated_at IS NULL
    AND a.start_at <= now()
    AND a.end_at >= now()
  ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN v_inserted;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_active_campaign_notifications() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_active_campaign_notifications() TO authenticated;

-- Backfill existing real customer business events idempotently (no fake data)
-- Safe re-runnable INSERT ... ON CONFLICT DO NOTHING so existing users see accurate history
DO $$
DECLARE
  v_rate numeric(12, 6) := 0.100000;
BEGIN
  SELECT COALESCE(points_to_inr_rate, 0.100000)
  INTO v_rate
  FROM public.reward_settings
  WHERE singleton_key = 'global'
  LIMIT 1;

  -- Backfill existing published active campaigns
  INSERT INTO public.notifications (
    user_id, category, notification_type, title, body,
    reference_type, reference_id, destination_route, badge_label,
    metadata, deduplication_key, created_at
  )
  SELECT
    p.id,
    'announcements',
    CASE
      WHEN lower(COALESCE(a.title, '') || ' ' || COALESCE(a.offer_details, '')) ~ '(festival|festive|diwali|holi|eid|onam|pongal|christmas|halloween|new year|mahotsav)'
        THEN 'festival_announcement'
      ELSE 'campaign_published'
    END,
    a.title,
    COALESCE(
      NULLIF(trim(COALESCE(a.offer_details, '')), ''),
      'New exclusive campaign live through ' || to_char((a.end_at AT TIME ZONE 'Asia/Kolkata'), 'DD Mon YYYY') || '.'
    ),
    'advertisement',
    a.id,
    '/home',
    CASE
      WHEN lower(COALESCE(a.title, '') || ' ' || COALESCE(a.offer_details, '')) ~ '(festival|festive|diwali|holi|eid|onam|pongal|christmas|halloween|new year|mahotsav)'
        THEN 'Festive'
      ELSE 'Promo'
    END,
    jsonb_strip_nulls(jsonb_build_object(
      'advertisement_id', a.id,
      'title', a.title,
      'offer_details', a.offer_details,
      'image_url', a.image_url,
      'start_at', a.start_at,
      'end_at', a.end_at
    )),
    'ad_campaign:' || a.id::text,
    COALESCE(a.published_at, a.created_at)
  FROM public.advertisements a
  CROSS JOIN public.profiles p
  WHERE a.status = 'published'
    AND a.deactivated_at IS NULL
    AND a.start_at <= now()
    AND a.end_at >= now()
    AND p.approval_status = 'approved'
    AND NOT EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE au.user_id = p.id AND au.status = 'active'
    )
  ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;

  -- Backfill existing redeemed / expired / rejected / flagged claims
  INSERT INTO public.notifications (
    user_id, category, notification_type, title, body,
    points_amount, cash_value, currency_code,
    reference_type, reference_id, destination_route,
    metadata, deduplication_key, created_at
  )
  SELECT
    c.user_id,
    'claims',
    CASE
      WHEN c.status = 'redeemed' THEN 'claim_redeemed'
      WHEN c.status = 'expired' THEN 'claim_expired'
      ELSE 'claim_rejected'
    END,
    CASE
      WHEN c.status = 'redeemed' THEN 'Claim Reward Redeemed'
      WHEN c.status = 'expired' THEN 'Claim QR Expired'
      WHEN c.audit_status = 'flagged' THEN 'Claim Flagged at POS'
      ELSE 'Claim Rejected'
    END,
    CASE
      WHEN c.status = 'redeemed' THEN
        c.points || ' pts redeemed for ₹' || trim(to_char(c.discount_amount, 'FM999999990.00')) || ' (' || COALESCE(NULLIF(trim(c.reward_name), ''), 'Instant POS Bill Discount') || ') at ' || COALESCE(NULLIF(trim(c.merchant_name), ''), NULLIF(trim(c.branch_name), ''), 'Partner Counter') || '. Ref: ' || c.claim_reference || '.'
      WHEN c.status = 'expired' THEN
        'Dynamic QR ' || c.claim_reference || ' expired. ' || c.points || ' reserved pts were returned to your available balance.'
      ELSE
        'Claim ' || c.claim_reference || ' (' || c.points || ' pts) at ' || COALESCE(NULLIF(trim(c.merchant_name), ''), NULLIF(trim(c.branch_name), ''), 'Partner Counter') || ': ' || COALESCE(NULLIF(trim(c.rejected_reason), ''), NULLIF(trim(c.flagged_reason), ''), 'Verification declined at counter') || '. Reserved pts released.'
    END,
    CASE WHEN c.status = 'redeemed' THEN -c.points ELSE c.points END,
    c.discount_amount,
    'INR',
    'reward_claim',
    c.id,
    CASE WHEN c.status = 'expired' THEN '/home' ELSE '/activity-history' END,
    jsonb_strip_nulls(jsonb_build_object(
      'claim_id', c.id,
      'claim_reference', c.claim_reference,
      'reward_name', COALESCE(NULLIF(trim(c.reward_name), ''), 'Instant POS Bill Discount'),
      'merchant_name', COALESCE(NULLIF(trim(c.merchant_name), ''), NULLIF(trim(c.branch_name), ''), 'Partner Counter'),
      'branch_name', c.branch_name,
      'bill_number', c.bill_number,
      'audit_status', c.audit_status,
      'points', c.points,
      'discount_amount', c.discount_amount,
      'scroll_target', CASE WHEN c.status = 'expired' THEN 'wallet' ELSE NULL END
    )),
    CASE
      WHEN c.status = 'redeemed' THEN 'claim_redeemed:' || COALESCE(c.qr_token_id::text, c.id::text)
      WHEN c.status = 'expired' THEN 'claim_expired:' || c.id::text
      ELSE 'claim_rejected:' || c.id::text
    END,
    COALESCE(c.redeemed_at, c.released_at, c.updated_at, c.created_at)
  FROM public.reward_claims c
  WHERE c.status IN ('redeemed', 'expired')
     OR (c.status = 'cancelled' AND COALESCE(c.audit_status, '') IN ('rejected', 'flagged'))
  ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;

  -- Backfill merged POS merchant rewards (combines instant + future rows per bill)
  INSERT INTO public.notifications (
    user_id, category, notification_type, title, body,
    points_amount, cash_value, currency_code,
    reference_type, reference_id, destination_route,
    metadata, deduplication_key, created_at
  )
  WITH pos_rows AS (
    SELECT
      t.*,
      'pos_reward:' || COALESCE(
        NULLIF(regexp_replace(COALESCE(t.idempotency_key, ''), ':(instant|future)$', ''), ''),
        NULLIF(COALESCE(t.metadata->>'bill_number', '') || ':' || COALESCE(t.metadata->>'qr_token_id', ''), ':'),
        t.id::text
      ) AS dedup_key,
      COALESCE(NULLIF(trim(t.metadata->>'branch_name'), ''), 'Partner POS') AS branch_label,
      NULLIF(trim(t.metadata->>'bill_number'), '') AS bill_label,
      COALESCE(t.cash_value, ROUND((ABS(t.points_delta) * COALESCE(t.points_to_inr_rate, v_rate))::numeric, 2)) AS row_cash
    FROM public.point_transactions t
    WHERE t.transaction_type = 'merchant_reward'
      AND t.points_delta > 0
  )
  SELECT
    p.user_id,
    'points_rewards',
    'pos_points_credited',
    'Points Credited at ' || MAX(p.branch_label),
    '+' || SUM(p.points_delta) || ' pts (≈ ₹' || trim(to_char(ROUND(SUM(p.row_cash)::numeric, 2), 'FM999999990.00')) || ') credited by ' || MAX(p.branch_label)
      || CASE WHEN MAX(p.bill_label) IS NOT NULL THEN ' • Bill #' || MAX(p.bill_label) ELSE '' END,
    SUM(p.points_delta)::integer,
    ROUND(SUM(p.row_cash)::numeric, 2),
    COALESCE(MAX(NULLIF(trim(p.currency_code), '')), 'INR'),
    'point_transaction',
    (ARRAY_AGG(p.id ORDER BY p.created_at ASC))[1],
    '/activity-history',
    jsonb_strip_nulls(jsonb_build_object(
      'instant_points', SUM(CASE WHEN COALESCE(p.is_locked_allocation, false) THEN 0 ELSE p.points_delta END),
      'locked_points', SUM(CASE WHEN COALESCE(p.is_locked_allocation, false) THEN p.points_delta ELSE 0 END),
      'branch_name', MAX(p.branch_label),
      'bill_number', MAX(p.bill_label)
    )),
    p.dedup_key,
    MIN(p.created_at)
  FROM pos_rows p
  GROUP BY p.user_id, p.dedup_key
  ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;

  -- Backfill existing streak / unlock / bonus / adjustment / standalone redemption transactions
  INSERT INTO public.notifications (
    user_id, category, notification_type, title, body,
    points_amount, cash_value, currency_code,
    reference_type, reference_id, destination_route, badge_label,
    metadata, deduplication_key, created_at
  )
  SELECT
    t.user_id,
    CASE
      WHEN t.transaction_type = 'discount_redemption' THEN 'claims'
      ELSE 'points_rewards'
    END,
    CASE
      WHEN t.transaction_type = 'daily_streak' THEN
        CASE
          WHEN trim(COALESCE(t.metadata->>'streak_day', '')) = '7' THEN 'streak_milestone_completed'
          ELSE 'daily_streak_claimed'
        END
      WHEN t.transaction_type = 'streak_unlock' THEN 'locked_points_released'
      WHEN t.transaction_type = 'discount_redemption' THEN 'claim_redeemed'
      WHEN lower(trim(COALESCE(t.metadata->>'source', ''))) IN ('festival_bonus', 'campaign_bonus')
        OR (t.transaction_type = 'point_adjustment' AND lower(COALESCE(t.title, '')) LIKE '%festival%')
        THEN 'festival_bonus_credited'
      ELSE 'admin_point_adjustment'
    END,
    CASE
      WHEN t.transaction_type = 'daily_streak' THEN
        CASE
          WHEN trim(COALESCE(t.metadata->>'streak_day', '')) = '7' THEN '7-Day Streak Milestone Completed!'
          WHEN NULLIF(trim(t.metadata->>'streak_day'), '') IS NOT NULL THEN 'Daily Login Streak Day ' || trim(t.metadata->>'streak_day') || ' Claimed'
          ELSE 'Daily Login Streak Claimed'
        END
      WHEN t.transaction_type = 'streak_unlock' THEN 'Milestone Reward Unlocked!'
      WHEN t.transaction_type = 'discount_redemption' THEN 'Claim Reward Redeemed'
      WHEN lower(trim(COALESCE(t.metadata->>'source', ''))) IN ('festival_bonus', 'campaign_bonus')
        OR (t.transaction_type = 'point_adjustment' AND lower(COALESCE(t.title, '')) LIKE '%festival%')
        THEN COALESCE(NULLIF(trim(t.title), ''), 'Festival Bonus Credited')
      ELSE COALESCE(NULLIF(trim(t.title), ''), 'Points Account Adjustment')
    END,
    CASE
      WHEN t.transaction_type = 'daily_streak' THEN
        '+' || ABS(t.points_delta) || ' pts added to your daily streak progress.'
      WHEN t.transaction_type = 'streak_unlock' THEN
        'Your ' || ABS(t.points_delta) || ' locked points have completed settlement clearance and are now available.'
      WHEN t.transaction_type = 'discount_redemption' THEN
        ABS(t.points_delta) || ' pts redeemed for ₹'
          || trim(to_char(COALESCE(t.cash_value, ROUND((ABS(t.points_delta) * COALESCE(t.points_to_inr_rate, v_rate))::numeric, 2)), 'FM999999990.00'))
          || ' cashier discount at ' || COALESCE(NULLIF(trim(t.metadata->>'branch_name'), ''), 'Partner POS') || '.'
      WHEN lower(trim(COALESCE(t.metadata->>'source', ''))) IN ('festival_bonus', 'campaign_bonus')
        OR (t.transaction_type = 'point_adjustment' AND lower(COALESCE(t.title, '')) LIKE '%festival%') THEN
        '+' || ABS(t.points_delta) || ' pts (≈ ₹'
          || trim(to_char(COALESCE(t.cash_value, ROUND((ABS(t.points_delta) * COALESCE(t.points_to_inr_rate, v_rate))::numeric, 2)), 'FM999999990.00'))
          || ') • ' || COALESCE(NULLIF(trim(t.description), ''), 'Promotional campaign bonus credited.')
      ELSE
        (CASE WHEN t.points_delta >= 0 THEN '+' ELSE '' END) || t.points_delta || ' pts (≈ ₹'
          || trim(to_char(COALESCE(t.cash_value, ROUND((ABS(t.points_delta) * COALESCE(t.points_to_inr_rate, v_rate))::numeric, 2)), 'FM999999990.00'))
          || ') • ' || COALESCE(NULLIF(trim(t.description), ''), 'Updated by SHIIFTEX administrator.')
    END,
    t.points_delta,
    COALESCE(t.cash_value, ROUND((ABS(t.points_delta) * COALESCE(t.points_to_inr_rate, v_rate))::numeric, 2)),
    COALESCE(NULLIF(trim(t.currency_code), ''), 'INR'),
    CASE WHEN t.transaction_type = 'discount_redemption' THEN 'reward_claim' WHEN t.transaction_type = 'streak_unlock' THEN 'point_allocation' ELSE 'point_transaction' END,
    CASE WHEN t.transaction_type IN ('discount_redemption', 'streak_unlock') THEN t.reference_id ELSE t.id END,
    CASE WHEN t.transaction_type IN ('daily_streak', 'streak_unlock') THEN '/home' ELSE '/activity-history' END,
    CASE
      WHEN lower(trim(COALESCE(t.metadata->>'source', ''))) IN ('festival_bonus', 'campaign_bonus')
        OR (t.transaction_type = 'point_adjustment' AND lower(COALESCE(t.title, '')) LIKE '%festival%')
        THEN 'Festive'
      ELSE NULL
    END,
    (COALESCE(t.metadata, '{}'::jsonb) - 'admin_id' - 'admin_email')
      || CASE
           WHEN t.transaction_type = 'daily_streak' THEN jsonb_build_object('scroll_target', 'streak')
           WHEN t.transaction_type = 'streak_unlock' THEN jsonb_build_object('scroll_target', 'wallet')
           ELSE '{}'::jsonb
         END,
    CASE
      WHEN t.transaction_type = 'daily_streak' AND NULLIF(trim(t.metadata->>'cycle_date'), '') IS NOT NULL AND NULLIF(trim(t.metadata->>'streak_day'), '') IS NOT NULL THEN
        'daily_streak:' || trim(t.metadata->>'cycle_date') || ':d' || trim(t.metadata->>'streak_day')
      WHEN t.transaction_type = 'streak_unlock' THEN
        'locked_release:' || COALESCE(t.reference_id::text, t.id::text)
      WHEN t.transaction_type = 'discount_redemption' THEN
        'claim_redeemed:' || COALESCE(t.reference_id::text, t.id::text)
      ELSE 'tx:' || t.id::text
    END,
    t.created_at
  FROM public.point_transactions t
  WHERE t.transaction_type IN ('daily_streak', 'streak_unlock', 'point_adjustment', 'discount_redemption')
  ORDER BY t.created_at ASC
  ON CONFLICT (user_id, deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING;
END $$;
