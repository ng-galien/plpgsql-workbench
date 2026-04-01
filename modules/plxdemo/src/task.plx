entity plxdemo.task uses auditable:
  table: plxdemo.task
  uri: 'plxdemo://task'
  icon: '✓'
  label: 'plxdemo.entity_task'
  list_order: 'created_at desc'

  fields:
    title text required
    description text?
    priority text? default('normal')
    done boolean? default(false)

  validate create:
    assert coalesce(p_row.priority, 'normal') = 'low' or coalesce(p_row.priority, 'normal') = 'normal' or coalesce(p_row.priority, 'normal') = 'high', plxdemo.err_priority_invalid

  validate update:
    assert coalesce(p_row.priority, 'normal') = 'low' or coalesce(p_row.priority, 'normal') = 'normal' or coalesce(p_row.priority, 'normal') = 'high', plxdemo.err_priority_invalid

  view:
    compact: [title, priority, done]
    standard: [title, description, priority, done]
    expanded: [title, description, priority, done, created_at, updated_at]
    form:
      'plxdemo.section_task':
        {key: title, type: text, label: plxdemo.field_title, required: true}
        {key: description, type: textarea, label: plxdemo.field_description}
        {key: priority, type: select, label: plxdemo.field_priority}

  actions:
    edit: {label: plxdemo.action_edit, icon: '✏', variant: muted}
    delete: {label: plxdemo.action_delete, icon: '×', variant: danger, confirm: plxdemo.confirm_delete}
