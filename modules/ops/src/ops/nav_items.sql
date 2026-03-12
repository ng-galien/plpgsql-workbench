CREATE OR REPLACE FUNCTION ops.nav_items()
 RETURNS jsonb
 LANGUAGE sql
AS $function$
SELECT '[
    {"href":"/","label":"Dashboard","icon":"monitor"},
    {"href":"/modules","label":"Modules","icon":"package"},
    {"href":"/dashboard","label":"Sante","icon":"activity"},
    {"href":"/agents","label":"Agents","icon":"terminal"},
    {"href":"/messages","label":"Messages","icon":"mail"},
    {"href":"/hooks","label":"Hooks","icon":"shield"}
  ]'::jsonb;
$function$;
