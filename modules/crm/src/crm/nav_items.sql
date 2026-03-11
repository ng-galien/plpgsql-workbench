CREATE OR REPLACE FUNCTION crm.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '[{"href":"/","label":"Clients","icon":"users"}]'::jsonb;
$function$;
