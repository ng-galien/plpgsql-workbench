CREATE OR REPLACE FUNCTION pgv_qa.nav_options()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT '{"burger": true}'::jsonb;
$function$;
