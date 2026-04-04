entity hr.employee uses auditable:
  table: hr.employee
  uri: 'hr://employee'
  label: 'hr.entity_employee'
  list_order: 'last_name, first_name'

  fields:
    employee_code text default('')
    last_name text required
    first_name text required
    email text?
    phone text?
    birth_date date?
    gender text default('')
    nationality text default('')
    position text default('')
    qualification text default('')
    department text default('')
    contract_type text default('cdi')
    hire_date date required
    end_date date?
    gross_salary numeric?
    weekly_hours numeric default(35)
    status text default('active')
    notes text default('')

  validate:
    gender_valid: """
      coalesce(p_input->>'gender', '') in ('', 'M', 'F')
    """
    contract_valid: """
      coalesce(p_input->>'contract_type', 'cdi') in ('cdi', 'cdd', 'apprenticeship', 'internship', 'temp')
    """
    status_valid: """
      coalesce(p_input->>'status', 'active') in ('active', 'inactive')
    """

  strategies:
    read.query: hr._employee_read_query
    list.query: hr._employee_list_query

  view:
    compact: [last_name, first_name, position, status]
    standard:
      fields: [last_name, first_name, email, phone, position, department, contract_type, status]
      stats:
        {key: cp_remaining, label: hr.stat_cp_remaining}
        {key: rtt_remaining, label: hr.stat_rtt_remaining}
        {key: hours_30d, label: hr.stat_hours_30d}
      related:
        {entity: 'hr://leave_request', filter: 'employee_id={id}', label: hr.rel_absences}
        {entity: 'hr://timesheet', filter: 'employee_id={id}', label: hr.rel_timesheets}
    expanded:
      fields: [employee_code, last_name, first_name, email, phone, birth_date, gender, nationality, position, qualification, department, contract_type, hire_date, end_date, gross_salary, weekly_hours, status, notes, created_at, updated_at]
      stats:
        {key: cp_remaining, label: hr.stat_cp_remaining}
        {key: rtt_remaining, label: hr.stat_rtt_remaining}
        {key: hours_30d, label: hr.stat_hours_30d}
        {key: leave_count, label: hr.stat_leave_count}
      related:
        {entity: 'hr://leave_request', filter: 'employee_id={id}', label: hr.rel_absences}
        {entity: 'hr://timesheet', filter: 'employee_id={id}', label: hr.rel_timesheets}
    form:
      'hr.section_identity':
        {key: employee_code, type: text, label: hr.field_employee_code}
        {key: last_name, type: text, label: hr.field_last_name, required: true}
        {key: first_name, type: text, label: hr.field_first_name, required: true}
        {key: email, type: email, label: hr.field_email}
        {key: phone, type: tel, label: hr.field_phone}
        {key: birth_date, type: date, label: hr.field_birth_date}
        {key: gender, type: select, label: hr.field_gender, options: hr.gender_options}
        {key: nationality, type: text, label: hr.field_nationality}
      'hr.section_position':
        {key: position, type: text, label: hr.field_position}
        {key: qualification, type: text, label: hr.field_qualification}
        {key: department, type: text, label: hr.field_department}
      'hr.section_contract':
        {key: contract_type, type: select, label: hr.field_contract_type, options: hr.contract_type_options}
        {key: hire_date, type: date, label: hr.field_hire_date, required: true}
        {key: end_date, type: date, label: hr.field_end_date}
        {key: gross_salary, type: number, label: hr.field_gross_salary}
        {key: weekly_hours, type: number, label: hr.field_weekly_hours}
      'hr.section_notes':
        {key: notes, type: textarea, label: hr.field_notes}

  actions:
    edit:       {label: hr.action_edit, variant: muted}
    deactivate: {label: hr.action_deactivate, variant: warning}
    activate:   {label: hr.action_activate}
    delete:     {label: hr.action_delete, variant: danger, confirm: hr.confirm_delete_employee}
