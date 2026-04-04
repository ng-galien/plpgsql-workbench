module expense

import jsonb_build_object as obj
import jsonb_build_array as arr

include "./category.plx"
include "./report.plx"
include "./line.plx"
include "./helpers.plx"
include "./report.spec.plx"

export expense.category
export expense.expense_report
export expense.line

fn expense.brand() -> text [stable]:
  return i18n.t('expense.brand')

fn expense.nav_items() -> jsonb [stable]:
  return arr(
    obj('href', '/', 'label', i18n.t('expense.nav_reports'), 'icon', 'receipt', 'entity', 'expense_report'),
    obj('href', '/categories', 'label', i18n.t('expense.nav_categories'), 'icon', 'tag', 'entity', 'category')
  )
