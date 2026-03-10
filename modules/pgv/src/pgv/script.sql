CREATE OR REPLACE FUNCTION pgv.script(p_js text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<script>' || p_js || '</script>';
$function$;
