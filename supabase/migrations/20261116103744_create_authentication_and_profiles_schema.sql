-- Migration: create_authentication_and_profiles_schema
-- Created for SHIIFTEX Authentication & Account Approval Module

-- 1. Create non-exposed private schema for internal security definer helpers & triggers
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO postgres, service_role, authenticated;

-- 2. Mobile number normalization helper
CREATE OR REPLACE FUNCTION private.normalize_mobile(p_mobile text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  v_cleaned text;
BEGIN
  IF p_mobile IS NULL THEN
    RETURN NULL;
  END IF;
  v_cleaned := regexp_replace(trim(p_mobile), '[^0-9+]', '', 'g');
  IF v_cleaned = '' THEN
    RETURN '';
  END IF;
  IF left(v_cleaned, 1) <> '+' THEN
    IF length(v_cleaned) = 10 THEN
      v_cleaned := '+91' || v_cleaned;
    ELSIF length(v_cleaned) = 12 AND left(v_cleaned, 2) = '91' THEN
      v_cleaned := '+' || v_cleaned;
    ELSE
      v_cleaned := '+' || v_cleaned;
    END IF;
  END IF;
  RETURN v_cleaned;
END;
$$;

REVOKE EXECUTE ON FUNCTION private.normalize_mobile(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.normalize_mobile(text) TO authenticated, postgres, service_role;

-- 3. Separate Admin Authorization table
CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.admin_users FROM PUBLIC, anon;
GRANT SELECT ON public.admin_users TO authenticated;

CREATE POLICY admin_users_select_self
  ON public.admin_users
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- 4. Customer Profiles table (no role column, no access code)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL,
  email text NOT NULL UNIQUE,
  mobile_number text NOT NULL UNIQUE,
  approval_status text NOT NULL DEFAULT 'pending'
    CHECK (approval_status IN ('pending', 'approved', 'rejected', 'suspended')),
  approved_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at timestamptz,
  rejection_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS profiles_approved_by_idx ON public.profiles(approved_by);
CREATE INDEX IF NOT EXISTS profiles_approval_status_idx ON public.profiles(approval_status);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;

REVOKE ALL ON public.profiles FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;

-- 5. Private RLS helper functions
CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_users
    WHERE user_id = (SELECT auth.uid())
  );
$$;

REVOKE EXECUTE ON FUNCTION private.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_admin() TO authenticated;

CREATE OR REPLACE FUNCTION private.is_approved_customer()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = (SELECT auth.uid())
      AND approval_status = 'approved'
  );
$$;

REVOKE EXECUTE ON FUNCTION private.is_approved_customer() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.is_approved_customer() TO authenticated;

-- 6. RLS Policies for public.profiles
CREATE POLICY profiles_select_own_or_admin
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = id OR (SELECT private.is_admin()));

CREATE POLICY profiles_insert_own_pending
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT auth.uid()) = id
    AND approval_status = 'pending'
    AND approved_by IS NULL
    AND approved_at IS NULL
    AND rejection_reason IS NULL
  );

CREATE POLICY profiles_update_own_or_admin
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = id OR (SELECT private.is_admin()))
  WITH CHECK ((SELECT auth.uid()) = id OR (SELECT private.is_admin()));

-- 7. Trigger to protect approval columns from non-admin modification and maintain updated_at
CREATE OR REPLACE FUNCTION private.protect_profile_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at := now();
  IF NEW.mobile_number IS NOT NULL AND NEW.mobile_number <> '' THEN
    NEW.mobile_number := private.normalize_mobile(NEW.mobile_number);
  END IF;
  IF NEW.email IS NOT NULL THEN
    NEW.email := lower(trim(NEW.email));
  END IF;

  IF current_user IN ('authenticated', 'anon') AND NOT private.is_admin() THEN
    IF NEW.approval_status IS DISTINCT FROM OLD.approval_status
       OR NEW.approved_by IS DISTINCT FROM OLD.approved_by
       OR NEW.approved_at IS DISTINCT FROM OLD.approved_at
       OR NEW.rejection_reason IS DISTINCT FROM OLD.rejection_reason
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
    THEN
      RAISE EXCEPTION 'UNAUTHORIZED_APPROVAL_UPDATE: Only administrators can modify account approval status.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION private.protect_profile_columns() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE TRIGGER tr_protect_profile_columns
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION private.protect_profile_columns();

-- 8. Prevent duplicate mobile number before auth.users signup
CREATE OR REPLACE FUNCTION private.check_duplicate_registration_before_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_mobile text;
BEGIN
  v_mobile := private.normalize_mobile(NEW.raw_user_meta_data->>'mobile_number');

  IF v_mobile IS NOT NULL AND v_mobile <> '' THEN
    IF EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.mobile_number = v_mobile
        AND p.id <> NEW.id
    ) OR EXISTS (
      SELECT 1 FROM auth.users u
      WHERE private.normalize_mobile(u.raw_user_meta_data->>'mobile_number') = v_mobile
        AND u.id <> NEW.id
    ) THEN
      RAISE EXCEPTION 'MOBILE_ALREADY_REGISTERED: This mobile number is already registered.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION private.check_duplicate_registration_before_signup() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE TRIGGER tr_check_duplicate_registration
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION private.check_duplicate_registration_before_signup();

-- 9. Idempotent customer profile creation upon email verification
CREATE OR REPLACE FUNCTION private.handle_verified_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_full_name text;
  v_mobile text;
  v_email text;
BEGIN
  IF NEW.email_confirmed_at IS NOT NULL AND NEW.email IS NOT NULL THEN
    v_email := lower(trim(NEW.email));
    v_full_name := trim(COALESCE(
      NULLIF(trim(NEW.raw_user_meta_data->>'full_name'), ''),
      NULLIF(trim(concat_ws(' ', NEW.raw_user_meta_data->>'first_name', NEW.raw_user_meta_data->>'last_name')), ''),
      split_part(v_email, '@', 1)
    ));
    v_mobile := private.normalize_mobile(COALESCE(
      NULLIF(trim(NEW.raw_user_meta_data->>'mobile_number'), ''),
      NULLIF(trim(NEW.phone), ''),
      '+910000000000'
    ));

    INSERT INTO public.profiles (
      id,
      full_name,
      email,
      mobile_number,
      approval_status,
      created_at,
      updated_at
    ) VALUES (
      NEW.id,
      v_full_name,
      v_email,
      v_mobile,
      'pending',
      now(),
      now()
    )
    ON CONFLICT (id) DO UPDATE
    SET
      email = EXCLUDED.email,
      full_name = CASE
        WHEN public.profiles.full_name = '' THEN EXCLUDED.full_name
        ELSE public.profiles.full_name
      END,
      mobile_number = CASE
        WHEN public.profiles.mobile_number IN ('', '+910000000000') THEN EXCLUDED.mobile_number
        ELSE public.profiles.mobile_number
      END,
      updated_at = now();
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION private.handle_verified_auth_user() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE TRIGGER tr_handle_verified_auth_user
  AFTER INSERT OR UPDATE OF email_confirmed_at ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION private.handle_verified_auth_user();

-- 10. Idempotent RPC for authenticated customer to ensure & fetch their profile after OTP verification
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.ensure_customer_profile(
  p_full_name text DEFAULT NULL,
  p_mobile_number text DEFAULT NULL
)
RETURNS public.profiles
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid;
  v_jwt jsonb;
  v_meta jsonb;
  v_profile public.profiles;
  v_full_name text;
  v_mobile text;
  v_email text;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Active session required.';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_uid;

  IF FOUND THEN
    RETURN v_profile;
  END IF;

  v_jwt := (SELECT auth.jwt());
  v_email := lower(trim(COALESCE(v_jwt->>'email', '')));
  IF v_email = '' THEN
    RAISE EXCEPTION 'EMAIL_NOT_VERIFIED: Email claim missing from session.';
  END IF;

  v_meta := COALESCE(v_jwt->'user_metadata', '{}'::jsonb);
  v_full_name := trim(COALESCE(
    NULLIF(trim(p_full_name), ''),
    NULLIF(trim(v_meta->>'full_name'), ''),
    NULLIF(trim(concat_ws(' ', v_meta->>'first_name', v_meta->>'last_name')), ''),
    split_part(v_email, '@', 1)
  ));
  v_mobile := private.normalize_mobile(COALESCE(
    NULLIF(trim(p_mobile_number), ''),
    NULLIF(trim(v_meta->>'mobile_number'), ''),
    NULLIF(trim(v_jwt->>'phone'), '')
  ));

  INSERT INTO public.profiles (
    id,
    full_name,
    email,
    mobile_number,
    approval_status
  ) VALUES (
    v_uid,
    v_full_name,
    v_email,
    v_mobile,
    'pending'
  )
  ON CONFLICT (id) DO UPDATE
  SET
    full_name = COALESCE(NULLIF(public.profiles.full_name, ''), EXCLUDED.full_name),
    mobile_number = COALESCE(NULLIF(public.profiles.mobile_number, ''), EXCLUDED.mobile_number),
    updated_at = now()
  RETURNING * INTO v_profile;

  RETURN v_profile;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.ensure_customer_profile(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_customer_profile(text, text) TO authenticated;

-- 11. Secure mobile number to email resolution for login (requires valid account password; never exposes user directory)
CREATE OR REPLACE FUNCTION public.resolve_mobile_login_email(
  p_mobile text,
  p_password text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_normalized text;
  v_email text;
BEGIN
  IF p_mobile IS NULL OR trim(p_mobile) = '' OR p_password IS NULL OR p_password = '' THEN
    RETURN NULL;
  END IF;

  v_normalized := private.normalize_mobile(p_mobile);

  SELECT lower(trim(u.email))
  INTO v_email
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  WHERE (
    p.mobile_number = v_normalized
    OR private.normalize_mobile(u.raw_user_meta_data->>'mobile_number') = v_normalized
  )
  AND u.encrypted_password IS NOT NULL
  AND u.encrypted_password = extensions.crypt(p_password, u.encrypted_password)
  LIMIT 1;

  RETURN v_email;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.resolve_mobile_login_email(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_mobile_login_email(text, text) TO anon, authenticated;
