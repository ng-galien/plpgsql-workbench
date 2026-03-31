-- Test: import aliases

import jsonb_build_object as obj
import jsonb_build_array as arr
import pgv.t as t
import pgv.badge as badge
import coalesce as co

fn test.nav_items() -> jsonb [stable]:
  return arr(
    obj('href', '/', 'label', t('test.nav_home'), 'icon', 'home'),
    obj('href', '/items', 'label', t('test.nav_items'), 'icon', 'list')
  )

fn test.status_badge(p_status text) -> text [stable]:
  return badge(
    case p_status when 'draft' then t('test.draft') else p_status end,
    case p_status when 'draft' then 'secondary' else 'muted' end
  )

fn test.safe_name(p_id int) -> text:
  name := (select co(name, 'unknown') from test.item where id = p_id)
  return name
