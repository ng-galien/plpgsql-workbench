test "leave request workflow":
  e := hr.employee_create({last_name: 'Leave', first_name: 'Test', hire_date: '2020-01-01'})
  emp_id := (e->>'id')::int

  lr := hr.leave_request_create({employee_id: emp_id, leave_type: 'paid_leave', start_date: '2026-07-01', end_date: '2026-07-05', day_count: 5})
  assert lr->>'status' = 'pending'
  assert lr->>'leave_type' = 'paid_leave'

  approved := hr.leave_request_approve(lr->>'id')
  r := hr.leave_request_read(lr->>'id')
  assert r->>'status' = 'approved'

  hr.leave_request_delete(lr->>'id')
  hr.employee_delete(e->>'id')

test "leave request reject":
  e := hr.employee_create({last_name: 'Reject', first_name: 'Test', hire_date: '2020-01-01'})
  emp_id := (e->>'id')::int

  lr := hr.leave_request_create({employee_id: emp_id, leave_type: 'rtt', start_date: '2026-08-01', end_date: '2026-08-01', day_count: 1})
  hr.leave_request_reject(lr->>'id')
  r := hr.leave_request_read(lr->>'id')
  assert r->>'status' = 'rejected'

  hr.leave_request_delete(lr->>'id')
  hr.employee_delete(e->>'id')

test "leave date validation":
  e := hr.employee_create({last_name: 'DateVal', first_name: 'Test', hire_date: '2020-01-01'})
  blocked := false
  try:
    hr.leave_request_create({employee_id: (e->>'id')::int, leave_type: 'paid_leave', start_date: '2026-07-10', end_date: '2026-07-05', day_count: 1})
  catch:
    blocked := true
  assert blocked = true
  hr.employee_delete(e->>'id')
