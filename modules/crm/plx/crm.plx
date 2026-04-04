module crm

import jsonb_build_object as obj
import jsonb_build_array as arr

include "./client.plx"
include "./client.spec.plx"
include "./contact.plx"
include "./interaction.plx"
include "./interaction.spec.plx"
include "./helpers.plx"

export crm.client
export crm.contact
export crm.interaction

fn crm.brand() -> text [stable]:
  return i18n.t('crm.brand')

fn crm.nav_items() -> jsonb [stable]:
  return arr(
    obj('href', '/', 'label', i18n.t('crm.nav_clients'), 'icon', 'users', 'entity', 'client'),
    obj('href', '/interactions', 'label', i18n.t('crm.nav_interactions'), 'icon', 'message-circle', 'entity', 'interaction'),
    obj('href', '/import', 'label', i18n.t('crm.nav_import'), 'icon', 'upload')
  )
