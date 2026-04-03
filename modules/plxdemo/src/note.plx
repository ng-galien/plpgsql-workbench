entity plxdemo.note uses auditable, soft_delete:
  table: plxdemo.note
  uri: 'plxdemo://note'
  icon: '✎'
  label: 'plxdemo.entity_note'
  list_order: 'created_at desc'

  fields:
    title text required
    body text?
    pinned boolean? default(false)

  view:
    compact: [title]
    standard: [title, body, pinned]
    expanded: [title, body, pinned, created_at, updated_at]
    form:
      'plxdemo.section_note':
        {key: title, type: text, label: plxdemo.field_title, required: true}
        {key: body, type: textarea, label: plxdemo.field_body}
        {key: pinned, type: checkbox, label: plxdemo.field_pinned}

  actions:
    edit: {label: plxdemo.action_edit, icon: '✏', variant: muted}
    delete: {label: plxdemo.action_delete, icon: '×', variant: danger, confirm: plxdemo.confirm_delete}
