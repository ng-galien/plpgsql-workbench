CREATE OR REPLACE FUNCTION stock.nav_items()
 RETURNS jsonb
 LANGUAGE sql
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('label', pgv.t('stock.nav_articles'),      'href', '/articles',      'entity', 'article'),
    jsonb_build_object('label', pgv.t('stock.nav_depots'),        'href', '/depots',         'entity', 'depot'),
    jsonb_build_object('label', pgv.t('stock.nav_mouvements'),    'href', '/mouvements'),
    jsonb_build_object('label', pgv.t('stock.nav_alertes'),       'href', '/alertes'),
    jsonb_build_object('label', pgv.t('stock.nav_valorisation'),  'href', '/valorisation'),
    jsonb_build_object('label', pgv.t('stock.nav_inventaire'),    'href', '/inventaire')
  );
$function$;
