entity hr.leave_balance:
  table: hr.leave_balance
  uri: 'hr://leave_balance'
  label: 'hr.entity_leave_balance'
  expose: false

  fields:
    employee_id int required ref(hr.employee)
    leave_type text required
    allocated numeric default(0)
    used numeric default(0)
