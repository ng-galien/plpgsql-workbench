CREATE OR REPLACE FUNCTION catalog.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
SELECT pgv.t('catalog.brand');
$function$;
