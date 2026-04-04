entity hr.leave_request uses auditable:
  table: hr.leave_request
  uri: 'hr://leave_request'
  label: 'hr.entity_absence'
  list_order: 'start_date desc'

  fields:
    employee_id int required ref(hr.employee)
    leave_type text required
    start_date date required
    end_date date required
    day_count numeric default(1)
    reason text?
    status text default('pending')

  validate:
    leave_type_valid: """
      p_input->>'leave_type' in ('paid_leave', 'rtt', 'sick', 'unpaid', 'training', 'other')
    """
    date_order: """
      (p_input->>'end_date')::date >= (p_input->>'start_date')::date
    """

  states pending -> approved:
    approve(pending -> approved)

  strategies:
    read.query: hr._leave_read_query
    list.query: hr._leave_list_query

  view:
    compact: [employee_id, leave_type, start_date, status]
    standard:
      fields: [employee_id, leave_type, start_date, end_date, day_count, status, reason]
      stats:
        {key: balance_remaining, label: hr.stat_balance_remaining}
    expanded:
      fields: [employee_id, leave_type, start_date, end_date, day_count, status, reason, created_at]
      stats:
        {key: balance_remaining, label: hr.stat_balance_remaining}
    form:
      'hr.section_leave':
        {key: employee_id, type: select, label: hr.field_employee, search: true, options: {source: 'hr://employee', display: last_name}, required: true}
        {key: leave_type, type: select, label: hr.field_leave_type, options: hr.leave_type_options, required: true}
        {key: start_date, type: date, label: hr.field_start_date, required: true}
        {key: end_date, type: date, label: hr.field_end_date, required: true}
        {key: day_count, type: number, label: hr.field_day_count}
        {key: reason, type: textarea, label: hr.field_reason}

  actions:
    approve: {label: hr.action_approve, variant: primary}
    reject:  {label: hr.action_reject, variant: danger}
    cancel:  {label: hr.action_cancel, variant: warning}
    delete:  {label: hr.action_delete, variant: danger, confirm: hr.confirm_delete_absence}
