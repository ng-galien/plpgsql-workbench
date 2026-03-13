CREATE OR REPLACE FUNCTION stock.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('label', pgv.t('stock.nav_articles'),      'href', '/articles'),
    jsonb_build_object('label', pgv.t('stock.nav_depots'),        'href', '/depots'),
    jsonb_build_object('label', pgv.t('stock.nav_mouvements'),    'href', '/mouvements'),
    jsonb_build_object('label', pgv.t('stock.nav_alertes'),       'href', '/alertes'),
    jsonb_build_object('label', pgv.t('stock.nav_valorisation'),  'href', '/valorisation'),
    jsonb_build_object('label', pgv.t('stock.nav_inventaire'),    'href', '/inventaire')
  );
$function$;
