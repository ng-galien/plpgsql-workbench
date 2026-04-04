module asset

import jsonb_build_object as obj
import jsonb_build_array as arr

include "./item.plx"
include "./item.spec.plx"
include "./helpers.plx"

export asset.asset

fn asset.brand() -> text [stable]:
  return i18n.t('asset.brand')

fn asset.nav_items() -> jsonb [stable]:
  return arr(
    obj('href', '/', 'label', i18n.t('asset.nav_assets'), 'icon', 'image', 'entity', 'asset'),
    obj('href', '/upload', 'label', i18n.t('asset.nav_upload'), 'icon', 'upload')
  )
