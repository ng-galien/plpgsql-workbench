CREATE OR REPLACE FUNCTION hr.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT '[
    {"href":"/","label":"Salariés","icon":"users"},
    {"href":"/absences","label":"Absences","icon":"calendar"},
    {"href":"/timesheet","label":"Heures","icon":"clock"},
    {"href":"/registre","label":"Registre","icon":"book"}
  ]'::jsonb;
$function$;
