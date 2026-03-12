CREATE OR REPLACE FUNCTION project.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
SELECT '[{"href":"/","label":"Dashboard","icon":"home"},{"href":"/chantiers","label":"Chantiers","icon":"briefcase"},{"href":"/planning","label":"Planning","icon":"calendar"}]'::jsonb;
$function$;
