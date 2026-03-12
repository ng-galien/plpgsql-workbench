CREATE OR REPLACE FUNCTION ledger.nav_items()
 RETURNS jsonb
 LANGUAGE sql
AS $function$
SELECT '[
    {"href":"/","label":"Tableau de bord","icon":"home"},
    {"href":"/entries","label":"Écritures","icon":"list"},
    {"href":"/accounts","label":"Plan comptable","icon":"book"},
    {"href":"/balance","label":"Balance","icon":"scale"},
    {"href":"/exercice","label":"Exercice","icon":"calendar"},
    {"href":"/tva","label":"TVA","icon":"percent"},
    {"href":"/bilan","label":"Bilan","icon":"bar-chart"}
  ]'::jsonb;
$function$;
