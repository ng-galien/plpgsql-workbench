CREATE OR REPLACE FUNCTION workbench.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.t('workbench.brand');
$function$;
