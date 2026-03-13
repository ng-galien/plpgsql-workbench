CREATE OR REPLACE FUNCTION project.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT pgv.t('project.brand');
$function$;
