-- Entity test: expense.category via parser (Phase F)

import jsonb_build_object as obj
import jsonb_build_array as arr

entity expense.category uses auditable:
  table: expense.category
  uri: 'expense://category'
  icon: '🏷'
  label: 'expense.entity_category'
  list_order: 'name'

  fields:
    name text required
    accounting_code text?

  validate create:
    assert coalesce(p_row.accounting_code, '') != '999', expense.err_reserved_accounting_code

  view:
    compact: [name, accounting_code]
    standard: [name, accounting_code]
    expanded: [name, accounting_code, created_at]
    form:
      'expense.section_info':
        {key: name, type: text, label: expense.field_name, required: true}
        {key: accounting_code, type: text, label: expense.field_accounting_code}

  actions:
    edit: {label: expense.action_edit, icon: '✏', variant: muted}
    delete: {label: expense.action_delete, icon: '×', variant: danger, confirm: expense.confirm_delete_category}
