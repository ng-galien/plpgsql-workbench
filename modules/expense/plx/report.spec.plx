test "category crud":
  c := expense.category_create({name: 'Transport', accounting_code: '625'})
  assert c->>'name' = 'Transport'

  r := expense.category_read(c->>'id')
  assert r->>'name' = 'Transport'
  assert r->>'accounting_code' = '625'

  expense.category_delete(c->>'id')

test "expense report crud":
  r := expense.expense_report_create({author: 'Jean Dupont', start_date: '2026-01-01', end_date: '2026-01-31'})
  assert r->>'author' = 'Jean Dupont'
  assert r->>'status' = 'draft'

  read := expense.expense_report_read(r->>'id')
  assert read->>'author' = 'Jean Dupont'
  assert read->>'actions' != 'null'

  expense.expense_report_delete(r->>'id')

test "next reference format":
  r1 := expense.expense_report_create({author: 'Test', start_date: '2026-01-01', end_date: '2026-01-31'})
  r2 := expense.expense_report_create({author: 'Test', start_date: '2026-02-01', end_date: '2026-02-28'})
  assert r1->>'reference' is not null
  assert left(r1->>'reference', 4) = 'NDF-'
  assert r1->>'reference' != r2->>'reference'

  expense.expense_report_delete(r1->>'id')
  expense.expense_report_delete(r2->>'id')
