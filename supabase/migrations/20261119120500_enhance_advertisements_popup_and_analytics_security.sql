-- Migration: enhance_advertisements_popup_and_analytics_security
-- Safe backwards-compatible extensions to advertisements & advertisement_events
-- plus hardened SECURITY INVOKER RPCs and analytics summary view.

ALTER TABLE public.advertisements
  ADD COLUMN IF NOT EXISTS cta_label text DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS cta_action_type text DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS cta_action_value text DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS priority integer NOT NULL DEFAULT 0;

ALTER TABLE public.advertisement_events
  ADD COLUMN IF NOT EXISTS idempotency_key text DEFAULT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'advertisements_cta_action_type_check'
  ) THEN
    ALTER TABLE public.advertisements
      ADD CONSTRAINT advertisements_cta_action_type_check
      CHECK (
        cta_action_type IS NULL
        OR cta_action_type IN ('internal_route', 'external_url')
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'advertisement_events_event_type_check'
  ) THEN
    ALTER TABLE public.advertisement_events
      ADD CONSTRAINT advertisement_events_event_type_check
      CHECK (
        event_type IN (
          'impression',
          'dismissal',
          'auto_dismissal',
          'cta_click',
          'claim'
        )
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ads_active_lookup
  ON public.advertisements (status, start_at, end_at, priority DESC, created_at DESC)
  WHERE deactivated_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_ad_events_user_window
  ON public.advertisement_events (advertisement_id, user_id, event_type, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS advertisement_events_idempotency_uidx
  ON public.advertisement_events (
    user_id,
    advertisement_id,
    event_type,
    idempotency_key
  )
  WHERE idempotency_key IS NOT NULL;

-- Harden RLS on advertisement_events
DROP POLICY IF EXISTS "Customers can record ad events" ON public.advertisement_events;
DROP POLICY IF EXISTS "Customers can record own advertisement events" ON public.advertisement_events;
DROP POLICY IF EXISTS "Customers can view own advertisement events" ON public.advertisement_events;

CREATE POLICY "Customers can view own advertisement events"
  ON public.advertisement_events
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Customers can record own advertisement events"
  ON public.advertisement_events
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) IS NOT NULL
    AND (SELECT auth.uid()) = user_id
  );

-- Upgrade active customer advertisements RPC
DROP FUNCTION IF EXISTS public.get_active_customer_advertisements(uuid, text);

CREATE OR REPLACE FUNCTION public.get_active_customer_advertisements(
  p_customer_id uuid DEFAULT NULL,
  p_session_id text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  title text,
  offer_details text,
  image_url text,
  popup_duration_seconds integer,
  frequency_type text,
  frequency_limit integer,
  start_at timestamp with time zone,
  end_at timestamp with time zone,
  cta_label text,
  cta_action_type text,
  cta_action_value text,
  priority integer,
  published_at timestamp with time zone,
  server_now timestamp with time zone
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_caller_uid uuid := (SELECT auth.uid());
  v_is_admin boolean := COALESCE(private.is_admin(), false);
  v_uid uuid;
  v_session_id text := NULLIF(trim(COALESCE(p_session_id, '')), '');
  v_now timestamp with time zone := clock_timestamp();
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active customer session required.';
  END IF;

  IF NOT v_is_admin AND NOT COALESCE(private.is_approved_customer(), false) THEN
    RETURN;
  END IF;

  v_uid := CASE
    WHEN v_is_admin AND p_customer_id IS NOT NULL THEN p_customer_id
    ELSE v_caller_uid
  END;

  RETURN QUERY
  SELECT
    a.id,
    a.title,
    a.offer_details,
    a.image_url,
    GREATEST(1, COALESCE(a.popup_duration_seconds, 6))::integer AS popup_duration_seconds,
    COALESCE(NULLIF(lower(trim(a.frequency_type)), ''), 'once_per_session') AS frequency_type,
    GREATEST(1, COALESCE(a.frequency_limit, 1))::integer AS frequency_limit,
    a.start_at,
    a.end_at,
    a.cta_label,
    a.cta_action_type,
    a.cta_action_value,
    a.priority,
    a.published_at,
    v_now AS server_now
  FROM public.advertisements a
  WHERE a.status = 'published'
    AND a.deactivated_at IS NULL
    AND a.start_at <= v_now
    AND a.end_at >= v_now
    AND COALESCE(a.popup_duration_seconds, 6) > 0
    AND (
      CASE COALESCE(NULLIF(lower(trim(a.frequency_type)), ''), 'once_per_session')
        WHEN 'unlimited' THEN true
        WHEN 'always' THEN true
        WHEN 'once_per_user' THEN (
          SELECT COUNT(*)::integer
          FROM public.advertisement_events e
          WHERE e.advertisement_id = a.id
            AND e.user_id = v_uid
            AND e.event_type = 'impression'
        ) < GREATEST(1, COALESCE(a.frequency_limit, 1))
        WHEN 'once_per_day' THEN (
          SELECT COUNT(*)::integer
          FROM public.advertisement_events e
          WHERE e.advertisement_id = a.id
            AND e.user_id = v_uid
            AND e.event_type = 'impression'
            AND e.created_at >= (v_now - interval '24 hours')
        ) < GREATEST(1, COALESCE(a.frequency_limit, 1))
        WHEN 'once_per_week' THEN (
          SELECT COUNT(*)::integer
          FROM public.advertisement_events e
          WHERE e.advertisement_id = a.id
            AND e.user_id = v_uid
            AND e.event_type = 'impression'
            AND e.created_at >= (v_now - interval '7 days')
        ) < GREATEST(1, COALESCE(a.frequency_limit, 1))
        ELSE (
          v_session_id IS NULL
          OR (
            (
              SELECT COUNT(*)::integer
              FROM public.advertisement_events e
              WHERE e.advertisement_id = a.id
                AND e.user_id = v_uid
                AND e.session_id = v_session_id
                AND e.event_type = 'impression'
            ) < GREATEST(1, COALESCE(a.frequency_limit, 1))
            AND NOT (
              GREATEST(1, COALESCE(a.frequency_limit, 1)) = 1
              AND EXISTS (
                SELECT 1
                FROM public.advertisement_events e
                WHERE e.advertisement_id = a.id
                  AND e.user_id = v_uid
                  AND e.session_id = v_session_id
                  AND e.event_type IN ('dismissal', 'auto_dismissal', 'cta_click')
              )
            )
          )
        )
      END
    )
  ORDER BY a.priority DESC, COALESCE(a.published_at, a.created_at) DESC, a.id DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_active_customer_advertisements(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_active_customer_advertisements(uuid, text) TO authenticated;

-- Upgrade customer analytics tracking RPC (idempotent & SECURITY INVOKER)
DROP FUNCTION IF EXISTS public.track_advertisement_event(uuid, text, text, jsonb);

CREATE OR REPLACE FUNCTION public.track_advertisement_event(
  p_advertisement_id uuid,
  p_event_type text,
  p_session_id text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_event_type text := lower(trim(COALESCE(p_event_type, '')));
  v_session_id text := NULLIF(trim(COALESCE(p_session_id, '')), '');
  v_metadata jsonb := COALESCE(p_metadata, '{}'::jsonb);
  v_idem_key text := NULLIF(trim(COALESCE(p_metadata->>'idempotency_key', '')), '');
  v_existing_id uuid;
  v_event_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required to record advertisement events.';
  END IF;

  IF p_advertisement_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_ADVERTISEMENT: Advertisement ID is required.';
  END IF;

  IF v_event_type NOT IN ('impression', 'dismissal', 'auto_dismissal', 'cta_click', 'claim') THEN
    RAISE EXCEPTION 'INVALID_EVENT_TYPE: Unsupported advertisement event type "%".', v_event_type;
  END IF;

  IF v_idem_key IS NOT NULL THEN
    SELECT e.id
    INTO v_existing_id
    FROM public.advertisement_events e
    WHERE e.user_id = v_uid
      AND e.advertisement_id = p_advertisement_id
      AND e.event_type = v_event_type
      AND e.idempotency_key = v_idem_key
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
      RETURN v_existing_id;
    END IF;
  END IF;

  INSERT INTO public.advertisement_events (
    advertisement_id,
    user_id,
    event_type,
    session_id,
    idempotency_key,
    metadata
  ) VALUES (
    p_advertisement_id,
    v_uid,
    v_event_type,
    v_session_id,
    v_idem_key,
    v_metadata
  )
  ON CONFLICT (user_id, advertisement_id, event_type, idempotency_key)
  WHERE idempotency_key IS NOT NULL
  DO NOTHING
  RETURNING id INTO v_event_id;

  IF v_event_id IS NULL AND v_idem_key IS NOT NULL THEN
    SELECT e.id
    INTO v_event_id
    FROM public.advertisement_events e
    WHERE e.user_id = v_uid
      AND e.advertisement_id = p_advertisement_id
      AND e.event_type = v_event_type
      AND e.idempotency_key = v_idem_key
    LIMIT 1;
  END IF;

  RETURN v_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.track_advertisement_event(uuid, text, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.track_advertisement_event(uuid, text, text, jsonb) TO authenticated;

-- Admin analytics summary view (respects caller RLS via security_invoker = true)
CREATE OR REPLACE VIEW public.advertisement_analytics_summary
WITH (security_invoker = true)
AS
SELECT
  a.id AS advertisement_id,
  a.title,
  a.status,
  a.frequency_type,
  a.frequency_limit,
  a.popup_duration_seconds,
  a.start_at,
  a.end_at,
  COUNT(e.id) FILTER (WHERE e.event_type = 'impression')::bigint AS impressions_count,
  COUNT(DISTINCT e.user_id) FILTER (WHERE e.event_type = 'impression')::bigint AS unique_users_reached,
  COUNT(e.id) FILTER (WHERE e.event_type IN ('cta_click', 'claim'))::bigint AS clicks_count,
  COUNT(e.id) FILTER (WHERE e.event_type = 'dismissal')::bigint AS dismissals_count,
  COUNT(e.id) FILTER (WHERE e.event_type = 'auto_dismissal')::bigint AS auto_dismissals_count,
  CASE
    WHEN COUNT(e.id) FILTER (WHERE e.event_type = 'impression') > 0 THEN
      ROUND(
        (
          COUNT(e.id) FILTER (WHERE e.event_type IN ('cta_click', 'claim'))::numeric
          / COUNT(e.id) FILTER (WHERE e.event_type = 'impression')::numeric
        ) * 100.0,
        2
      )
    ELSE 0.00
  END AS ctr_percentage
FROM public.advertisements a
LEFT JOIN public.advertisement_events e
  ON e.advertisement_id = a.id
GROUP BY
  a.id,
  a.title,
  a.status,
  a.frequency_type,
  a.frequency_limit,
  a.popup_duration_seconds,
  a.start_at,
  a.end_at;

REVOKE ALL ON public.advertisement_analytics_summary FROM PUBLIC, anon;
GRANT SELECT ON public.advertisement_analytics_summary TO authenticated;
