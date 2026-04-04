entity expense.category:
  table: expense.category
  uri: 'expense://category'
  label: 'expense.entity_category'
  list_order: 'name'

  fields:
    name text required
    accounting_code text?

  view:
    compact: [name, accounting_code]
    standard:
      fields: [name, accounting_code]
    expanded:
      fields: [name, accounting_code, created_at]
    form:
      'expense.section_info':
        {key: name, type: text, label: expense.field_name, required: true}
        {key: accounting_code, type: text, label: expense.field_accounting_code}

  actions:
    edit:   {label: expense.action_edit, variant: muted}
    delete: {label: expense.action_delete, variant: danger, confirm: expense.confirm_delete_category}
