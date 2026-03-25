CREATE OR REPLACE FUNCTION stock.nav_items()
 RETURNS jsonb
 LANGUAGE sql
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('label', pgv.t('stock.nav_articles'),      'href', '/articles',      'entity', 'article',    'uri', 'stock://article'),
    jsonb_build_object('label', pgv.t('stock.nav_depots'),        'href', '/warehouses',    'entity', 'warehouse',  'uri', 'stock://warehouse'),
    jsonb_build_object('label', pgv.t('stock.nav_mouvements'),    'href', '/movements'),
    jsonb_build_object('label', pgv.t('stock.nav_alertes'),       'href', '/alerts'),
    jsonb_build_object('label', pgv.t('stock.nav_valorisation'),  'href', '/valuation'),
    jsonb_build_object('label', pgv.t('stock.nav_inventaire'),    'href', '/inventory')
  );
$function$;
