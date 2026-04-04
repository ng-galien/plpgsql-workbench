CREATE OR REPLACE FUNCTION i18n.t(p_key text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_lang text;
  v_value text;
BEGIN
  v_lang := coalesce(nullif(current_setting('i18n.lang', true), ''), 'fr');

  SELECT value INTO v_value FROM i18n.translation WHERE lang = v_lang AND key = p_key;
  IF FOUND THEN RETURN v_value; END IF;

  -- Fallback to French if different lang
  IF v_lang <> 'fr' THEN
    SELECT value INTO v_value FROM i18n.translation WHERE lang = 'fr' AND key = p_key;
    IF FOUND THEN RETURN v_value; END IF;
  END IF;

  -- Return key itself as last resort
  RETURN p_key;
END;
$function$;
