CREATE OR REPLACE FUNCTION ops.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT '[
    {"href":"/","label":"Dashboard","icon":"monitor"},
    {"href":"/messages","label":"Messages","icon":"mail"},
    {"href":"/hooks","label":"Hooks","icon":"shield"}
  ]'::jsonb;
$function$;
