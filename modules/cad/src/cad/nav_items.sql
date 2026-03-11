CREATE OR REPLACE FUNCTION cad.nav_items()
 RETURNS jsonb
 LANGUAGE sql
AS $function$
  SELECT '[{"href":"/","label":"Dessins"}]'::jsonb;
$function$;
