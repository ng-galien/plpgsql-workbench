CREATE OR REPLACE FUNCTION util.slugify(VARIADIC p_parts text[])
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_raw text;
  v_slug text;
BEGIN
  -- Concat non-null parts with space
  SELECT string_agg(p, ' ') INTO v_raw
  FROM unnest(p_parts) AS p
  WHERE p IS NOT NULL AND trim(p) != '';

  IF v_raw IS NULL THEN RETURN ''; END IF;

  v_slug := lower(v_raw);

  -- Unaccent via extension if available, else manual translate
  BEGIN
    v_slug := unaccent(v_slug);
  EXCEPTION WHEN undefined_function THEN
    v_slug := translate(v_slug,
      'éèêëàâäùûüïîôöçœæñ',
      'eeeeaaauuuiioocoanh');
  END;

  -- Replace non-alphanumeric with dash
  v_slug := regexp_replace(v_slug, '[^a-z0-9]+', '-', 'g');

  -- Trim dashes
  v_slug := trim(BOTH '-' FROM v_slug);

  RETURN v_slug;
END;
$function$;
