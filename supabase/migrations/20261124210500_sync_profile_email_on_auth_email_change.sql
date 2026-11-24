-- Migration: sync_profile_email_on_auth_email_change
-- Ensures public.profiles.email stays synchronized with auth.users.email
-- when an existing customer updates and confirms their email address, while
-- strictly preserving the existing user UUID (id), approval status, and all
-- foreign-key relationships.

CREATE OR REPLACE TRIGGER tr_handle_verified_auth_user
  AFTER INSERT OR UPDATE OF email_confirmed_at, email ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION private.handle_verified_auth_user();

CREATE OR REPLACE FUNCTION public.sync_customer_profile_email()
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
  v_jwt_email text;
  v_profile public.profiles;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  v_jwt_email := lower(trim(COALESCE((SELECT auth.jwt())->>'email', '')));

  IF v_jwt_email <> '' THEN
    UPDATE public.profiles p
    SET
      email = v_jwt_email,
      updated_at = now()
    WHERE p.id = v_uid
      AND p.email IS DISTINCT FROM v_jwt_email;
  END IF;

  SELECT *
  INTO v_profile
  FROM public.profiles p
  WHERE p.id = v_uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_NOT_FOUND: Customer profile does not exist for authenticated user.';
  END IF;

  RETURN v_profile;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sync_customer_profile_email() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_customer_profile_email() TO authenticated, service_role;
