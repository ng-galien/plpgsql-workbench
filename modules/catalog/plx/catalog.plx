module catalog

import jsonb_build_object as obj
import jsonb_build_array as arr

include "./unit.plx"
include "./category.plx"
include "./article.plx"
include "./supplier.plx"
include "./pricing.plx"
include "./helpers.plx"
include "./article.spec.plx"
include "./category.spec.plx"

export catalog.category
export catalog.article
export catalog.supplier_article

fn catalog.brand() -> text [stable]:
  return i18n.t('catalog.brand')

fn catalog.nav_items() -> jsonb [stable]:
  return arr(
    obj('href', '/', 'label', i18n.t('catalog.nav_articles'), 'icon', 'package', 'entity', 'article'),
    obj('href', '/categories', 'label', i18n.t('catalog.nav_categories'), 'icon', 'folder', 'entity', 'category'),
    obj('href', '/suppliers', 'label', i18n.t('catalog.nav_suppliers'), 'icon', 'truck', 'entity', 'supplier_article')
  )
