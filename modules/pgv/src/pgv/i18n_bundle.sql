CREATE OR REPLACE FUNCTION pgv.i18n_bundle(p_lang text DEFAULT 'fr'::text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  FROM pgv.i18n
  WHERE lang = p_lang;
$function$;
