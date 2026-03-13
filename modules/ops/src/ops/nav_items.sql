CREATE OR REPLACE FUNCTION ops.nav_items()
 RETURNS jsonb
 LANGUAGE sql
AS $function$
  SELECT '[
    {"href":"/","label":"Agents","icon":"terminal"},
    {"href":"/modules","label":"Modules","icon":"package"},
    {"href":"/tests","label":"Tests","icon":"check-circle"},
    {"href":"/dashboard","label":"Sante","icon":"activity"},
    {"href":"/hooks","label":"Hooks","icon":"shield"},
    {"href":"/docs","label":"Docs","icon":"book-open"}
  ]'::jsonb;
$function$;
