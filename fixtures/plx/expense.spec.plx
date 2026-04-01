-- expense.spec.plx — Test category CRUD lifecycle

test "category crud lifecycle":
  c := expense.category_create({name: 'Test', accounting_code: '601'})
  assert c->>'name' = 'Test'

  r := expense.category_read(c->>'id')
  assert r->>'name' = 'Test'
  assert r->>'actions' != 'null'

  u := expense.category_update(c->>'id', {name: 'Updated'})
  assert u->>'name' = 'Updated'

  d := expense.category_delete(c->>'id')
  assert d->>'name' = 'Updated'

test "category list":
  expense.category_create({name: 'Alpha', accounting_code: '701'})
  expense.category_create({name: 'Beta', accounting_code: '702'})
  n := select count(*) from expense.category_list()
  assert n >= 2
