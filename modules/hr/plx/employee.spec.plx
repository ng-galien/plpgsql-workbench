test "employee crud":
  e := hr.employee_create({last_name: 'Dupont', first_name: 'Marie', position: 'Chef de chantier', contract_type: 'cdi', hire_date: '2020-01-01'})
  assert e->>'last_name' = 'Dupont'
  assert e->>'first_name' = 'Marie'
  assert e->>'status' = 'active'

  r := hr.employee_read(e->>'id')
  assert r->>'last_name' = 'Dupont'
  assert (r->>'cp_remaining')::numeric >= 0::numeric

  u := hr.employee_update(e->>'id', {position: 'Conductrice de travaux'})
  assert u->>'position' = 'Conductrice de travaux'

  hr.employee_delete(e->>'id')

test "employee deactivate and activate":
  e := hr.employee_create({last_name: 'Toggle', first_name: 'Test', hire_date: '2020-01-01'})
  assert e->>'status' = 'active'

  hr.employee_deactivate(e->>'id')
  r1 := hr.employee_read(e->>'id')
  assert r1->>'status' = 'inactive'

  hr.employee_activate(e->>'id')
  r2 := hr.employee_read(e->>'id')
  assert r2->>'status' = 'active'

  hr.employee_delete(e->>'id')
