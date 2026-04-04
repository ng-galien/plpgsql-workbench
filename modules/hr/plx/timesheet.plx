entity hr.timesheet:
  table: hr.timesheet
  uri: 'hr://timesheet'
  label: 'hr.entity_timesheet'
  list_order: 'work_date desc'

  fields:
    employee_id int required ref(hr.employee)
    work_date date required
    hours numeric required
    description text default('')

  validate:
    hours_range: """
      (p_input->>'hours')::numeric >= 0 and (p_input->>'hours')::numeric <= 24
    """

  view:
    compact: [employee_id, work_date, hours]
    standard:
      fields: [employee_id, work_date, hours, description]
    expanded:
      fields: [employee_id, work_date, hours, description, created_at]
    form:
      'hr.section_timesheet':
        {key: employee_id, type: select, label: hr.field_employee, search: true, options: {source: 'hr://employee', display: last_name}, required: true}
        {key: work_date, type: date, label: hr.field_work_date, required: true}
        {key: hours, type: number, label: hr.field_hours, required: true}
        {key: description, type: text, label: hr.field_description}

  actions:
    edit:   {label: hr.action_edit, variant: muted}
    delete: {label: hr.action_delete, variant: danger}
