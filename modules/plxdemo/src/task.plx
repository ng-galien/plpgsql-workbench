entity plxdemo.task uses auditable:
  table: plxdemo.task
  uri: 'plxdemo://task'
  icon: '✓'
  label: 'plxdemo.entity_task'
  list_order: 'created_at desc'

  columns:
    rank int? default(0)
    note_id int? ref(plxdemo.note)
    project_id int? ref(plxdemo.project)

  payload:
    title text required
    description text?
    priority text? default('normal')
    done boolean? default(false)

  validate:
    priority_valid: """
      coalesce(p_input->>'priority', 'normal') in ('low', 'normal', 'high')
    """

  view:
    compact: [title, priority, done, rank, note_id]
    standard: [title, description, priority, done, rank, note_id, project_id]
    expanded: [title, description, priority, done, rank, note_id, project_id, created_at, updated_at]
    form:
      'plxdemo.section_task':
        {key: title, type: text, label: plxdemo.field_title, required: true}
        {key: description, type: textarea, label: plxdemo.field_description}
        {key: priority, type: select, label: plxdemo.field_priority}

  actions:
    edit: {label: plxdemo.action_edit, icon: '✏', variant: muted}
    delete: {label: plxdemo.action_delete, icon: '×', variant: danger, confirm: plxdemo.confirm_delete}
