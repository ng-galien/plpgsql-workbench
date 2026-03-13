CREATE OR REPLACE FUNCTION cad.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.t('cad.brand');
$function$;
