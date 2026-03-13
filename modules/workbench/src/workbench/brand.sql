CREATE OR REPLACE FUNCTION workbench.brand()
 RETURNS text
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 'Workbench'::text;
$function$;
