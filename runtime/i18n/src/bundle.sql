CREATE OR REPLACE FUNCTION i18n.bundle(p_lang text DEFAULT 'fr'::text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  FROM i18n.translation
  WHERE lang = p_lang;
$function$;
