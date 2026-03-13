CREATE OR REPLACE FUNCTION ops.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT '[
    {"href":"/agents","label":"Agents","icon":"terminal"},
    {"href":"/","label":"Dashboard","icon":"monitor"},
    {"href":"/modules","label":"Modules","icon":"package"},
    {"href":"/tests","label":"Tests","icon":"check-circle"},
    {"href":"/dashboard","label":"Sante","icon":"activity"},
    {"href":"/hooks","label":"Hooks","icon":"shield"},
    {"href":"/docs","label":"Docs","icon":"book-open"}
  ]'::jsonb;
$function$;
