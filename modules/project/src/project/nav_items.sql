CREATE OR REPLACE FUNCTION project.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '[{"href":"/","label":"Dashboard","icon":"home"},{"href":"/chantiers","label":"Chantiers","icon":"briefcase"}]'::jsonb;
$function$;
