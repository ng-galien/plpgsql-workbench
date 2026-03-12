CREATE OR REPLACE FUNCTION stock.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('label', 'Articles',    'href', '/articles'),
    jsonb_build_object('label', 'Dépôts',      'href', '/depots'),
    jsonb_build_object('label', 'Mouvements',  'href', '/mouvements'),
    jsonb_build_object('label', 'Alertes',     'href', '/alertes')
  );
$function$;
