-- Migration: Accept Arabic-Indic / Eastern Arabic-Indic digits in phone login
-- Date: 2026-09-17
-- When users type a phone number with the Arabic keyboard layout, the OS can
-- insert Arabic-Indic digits (٠-٩ / ۰-۹) instead of Latin (0-9). Stored
-- profiles always use Latin digits, so lookups returned nothing and login
-- failed with "no account linked". This folds both Arabic digit sets into
-- Latin digits before any normalization or comparison.

CREATE OR REPLACE FUNCTION public.fold_phone_digits(p_phone text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT translate(
        p_phone,
        '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹',
        '01234567890123456789'
    );
$$;

GRANT EXECUTE ON FUNCTION public.fold_phone_digits(text) TO anon;
GRANT EXECUTE ON FUNCTION public.fold_phone_digits(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.normalize_phone(p_phone text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_phone IS NULL THEN NULL
        ELSE (
            WITH t AS (SELECT public.fold_phone_digits(translate(p_phone, ' -()', '')) AS p)
            SELECT CASE
                WHEN left(p, 3) = '+20' THEN '0' || substr(p, 4)
                WHEN left(p, 4) = '0020' THEN '0' || substr(p, 5)
                ELSE p
            END
            FROM t
        )
    END;
$$;

GRANT EXECUTE ON FUNCTION public.normalize_phone(text) TO anon;
GRANT EXECUTE ON FUNCTION public.normalize_phone(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_email_by_phone(p_phone text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_email text;
    v_clean text;
BEGIN
    v_clean := public.normalize_phone(p_phone);

    SELECT email INTO v_email
    FROM public.profiles
    WHERE phone_number = v_clean
       OR public.normalize_phone(phone_number) = v_clean
    LIMIT 1;

    RETURN v_email;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_email_by_phone(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_email_by_phone(text) TO authenticated;