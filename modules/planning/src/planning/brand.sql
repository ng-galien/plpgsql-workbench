CREATE OR REPLACE FUNCTION planning.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.t('planning.brand');
$function$;
