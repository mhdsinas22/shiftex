-- Ensure public.resolve_mobile_login_email prioritizes public.profiles.mobile_number
-- and only falls back to auth.users.raw_user_meta_data->>'mobile_number' when
-- public.profiles.mobile_number is null, empty, or placeholder '+910000000000'.
CREATE OR REPLACE FUNCTION public.resolve_mobile_login_email(p_mobile text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_normalized text;
  v_digits text;
  v_email text;
BEGIN
  v_normalized := private.normalize_mobile(p_mobile);
  v_digits := regexp_replace(coalesce(p_mobile, ''), '[^0-9]', '', 'g');

  IF v_normalized = '' AND v_digits = '' THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(NULLIF(trim(p.email), ''), u.email)
  INTO v_email
  FROM public.profiles p
  LEFT JOIN auth.users u ON u.id = p.id
  WHERE p.mobile_number = v_normalized
     OR (length(v_digits) >= 10 AND right(regexp_replace(p.mobile_number, '[^0-9]', '', 'g'), 10) = right(v_digits, 10))
     OR (
       (p.mobile_number IS NULL OR p.mobile_number IN ('', '+910000000000'))
       AND length(v_digits) >= 10
       AND right(regexp_replace(coalesce(u.raw_user_meta_data->>'mobile_number', ''), '[^0-9]', '', 'g'), 10) = right(v_digits, 10)
     )
  LIMIT 1;

  RETURN lower(trim(v_email));
END;
$function$;
