CREATE OR REPLACE FUNCTION hr.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.t('hr.brand');
$function$;
