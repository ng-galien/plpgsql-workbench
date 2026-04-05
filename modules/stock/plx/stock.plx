module stock

include "./helpers.plx"
include "./article.plx"
include "./warehouse.plx"
include "./movement.plx"
include "./article.spec.plx"
include "./warehouse.spec.plx"

export stock.article
export stock.warehouse

fn stock.brand() -> text [stable]:
  return i18n.t('stock.brand')

fn stock.nav_items() -> jsonb [stable]:
  return """
    select jsonb_build_array(
      jsonb_build_object('label', i18n.t('stock.nav_articles'),   'href', '/articles',   'entity', 'article',   'uri', 'stock://article'),
      jsonb_build_object('label', i18n.t('stock.nav_warehouses'), 'href', '/warehouses', 'entity', 'warehouse', 'uri', 'stock://warehouse'),
      jsonb_build_object('label', i18n.t('stock.nav_movements'),  'href', '/movements'),
      jsonb_build_object('label', i18n.t('stock.nav_alerts'),     'href', '/alerts'),
      jsonb_build_object('label', i18n.t('stock.nav_valuation'),  'href', '/valuation'),
      jsonb_build_object('label', i18n.t('stock.nav_inventory'),  'href', '/inventory')
    )
  """
