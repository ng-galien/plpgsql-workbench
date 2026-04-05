test "warehouse crud":
  w := stock.warehouse_create({name: 'Main Workshop', type: 'workshop', address: '12 rue des Chênes'})
  assert w->>'name' = 'Main Workshop'
  assert w->>'active' = 'true'

  r := stock.warehouse_read(w->>'id')
  assert r->>'name' = 'Main Workshop'
  assert r->>'actions' != 'null'
  assert (r->>'article_count')::int = 0

  stock.warehouse_update(w->>'id', {address: '14 rue des Chênes'})
  r2 := stock.warehouse_read(w->>'id')
  assert r2->>'address' = '14 rue des Chênes'

  stock.warehouse_delete(w->>'id')

test "warehouse activate deactivate":
  w := stock.warehouse_create({name: 'Toggle Warehouse', type: 'storage'})

  stock.warehouse_deactivate(w->>'id')
  r := stock.warehouse_read(w->>'id')
  assert r->>'active' = 'false'

  stock.warehouse_activate(w->>'id')
  r2 := stock.warehouse_read(w->>'id')
  assert r2->>'active' = 'true'

  stock.warehouse_delete(w->>'id')
