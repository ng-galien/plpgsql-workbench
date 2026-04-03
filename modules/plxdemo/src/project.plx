entity plxdemo.project uses auditable, soft_delete:
  table: plxdemo.project
  uri: 'plxdemo://project'
  icon: '📁'
  label: 'plxdemo.entity_project'
  list_order: 'updated_at desc'

  fields:
    name text required unique
    code text required unique create_only
    description text?
    budget numeric?
    owner text?
    deadline date?

  states draft -> active -> completed -> archived:
    column: status

    activate(draft -> active):
      guard: coalesce((v_row->>'budget')::numeric, 0) > 0 and v_row->>'owner' is not null

    complete(active -> completed)

    archive(completed -> archived)

  update_states: [draft, active]

  validate:
    budget_positive: coalesce((p_input->>'budget')::numeric, 0) >= 0

  view:
    compact: [name, code, status]
    standard:
      fields: [name, code, description, budget, owner, deadline, status]
      stats:
        {key: task_count, label: plxdemo.stat_task_count}
    expanded: [name, code, description, budget, owner, deadline, status, created_at, updated_at]
    form:
      'plxdemo.section_project':
        {key: name, type: text, label: plxdemo.field_name, required: true}
        {key: code, type: text, label: plxdemo.field_code, required: true}
        {key: description, type: textarea, label: plxdemo.field_description}
        {key: budget, type: number, label: plxdemo.field_budget}
        {key: owner, type: text, label: plxdemo.field_owner}
        {key: deadline, type: date, label: plxdemo.field_deadline}

  actions:
    edit: {label: plxdemo.action_edit, icon: '✏', variant: muted}
    delete: {label: plxdemo.action_delete, icon: '×', variant: danger, confirm: plxdemo.confirm_delete}

  event activated(project_id int)

  on update(new, old):
    if new.status = 'active' and old.status = 'draft':
      emit activated(new.id)

fn plxdemo.project_create_kickoff_task(project_id int) -> void [definer]:
  """
    insert into plxdemo.task (project_id, payload)
    values (
      project_id,
      jsonb_build_object(
        'title', 'Kickoff',
        'description', 'Auto-created when the project is activated',
        'priority', 'normal',
        'done', false
      )
    )
  """
  return
