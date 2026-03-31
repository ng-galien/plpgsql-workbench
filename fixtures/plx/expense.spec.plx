-- expense.spec.plx — Test category CRUD lifecycle

test "category crud lifecycle":
  c := expense.category_create(row('Test', '601'))
  assert c->>'name' = 'Test'

  r := expense.category_read((c->>'id')::int)
  assert r->>'name' = 'Test'
  assert r->>'actions' != 'null'

  u := expense.category_update(row((c->>'id')::int, 'Updated', '601'))
  assert u->>'name' = 'Updated'

  d := expense.category_delete((c->>'id')::int)
  assert d->>'name' = 'Updated'

test "category list":
  expense.category_create(row('Alpha', '701'))
  expense.category_create(row('Beta', '702'))
  n := count(expense.category_list())
  assert n >= 2
