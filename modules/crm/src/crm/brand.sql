CREATE OR REPLACE FUNCTION crm.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.t('crm.brand');
$function$;
