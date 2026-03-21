CREATE OR REPLACE FUNCTION docs.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.t('docs.brand');
$function$;
