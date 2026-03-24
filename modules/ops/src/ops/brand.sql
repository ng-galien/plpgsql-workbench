CREATE OR REPLACE FUNCTION ops.brand()
 RETURNS text
 LANGUAGE sql
AS $function$
  SELECT pgv.t('ops.brand');
$function$;
