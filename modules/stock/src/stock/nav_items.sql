CREATE OR REPLACE FUNCTION stock.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
SELECT jsonb_build_array(
    jsonb_build_object('label', pgv.t('stock.nav_articles'),     'href', '/articles',      'entity', 'article',    'uri', 'stock://article'),
    jsonb_build_object('label', pgv.t('stock.nav_warehouses'),   'href', '/warehouses',    'entity', 'warehouse',  'uri', 'stock://warehouse'),
    jsonb_build_object('label', pgv.t('stock.nav_movements'),    'href', '/movements'),
    jsonb_build_object('label', pgv.t('stock.nav_alerts'),       'href', '/alerts'),
    jsonb_build_object('label', pgv.t('stock.nav_valuation'),    'href', '/valuation'),
    jsonb_build_object('label', pgv.t('stock.nav_inventory'),    'href', '/inventory')
  );
$function$;
