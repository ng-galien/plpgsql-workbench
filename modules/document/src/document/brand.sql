CREATE OR REPLACE FUNCTION document.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.t('document.brand');
$function$;
