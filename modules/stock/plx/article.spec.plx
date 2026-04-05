test "article crud":
  a := stock.article_create({reference: 'TEST-001', description: 'Oak beam 80x80', category: 'wood', unit: 'm'})
  assert a->>'reference' = 'TEST-001'
  assert a->>'active' = 'true'
  assert a->>'wap' = '0'

  r := stock.article_read(a->>'id')
  assert r->>'description' = 'Oak beam 80x80'
  assert r->>'actions' != 'null'
  assert (r->>'current_stock')::numeric = 0::numeric

  stock.article_update(a->>'id', {description: 'Oak beam 100x100'})
  r2 := stock.article_read(a->>'id')
  assert r2->>'description' = 'Oak beam 100x100'

  stock.article_delete(a->>'id')

test "article activate deactivate":
  a := stock.article_create({reference: 'TEST-ACT', description: 'Toggle article', category: 'hardware', unit: 'ea'})

  stock.article_deactivate(a->>'id')
  r := stock.article_read(a->>'id')
  assert r->>'active' = 'false'

  stock.article_activate(a->>'id')
  r2 := stock.article_read(a->>'id')
  assert r2->>'active' = 'true'

  stock.article_delete(a->>'id')

test "article options search":
  a := stock.article_create({reference: 'OPT-001', description: 'Stainless screw 5x50', category: 'hardware', unit: 'ea'})

  opts := stock.article_options('Stainless')
  assert jsonb_array_length(opts) >= 1
  assert opts->0->>'label' = 'Stainless screw 5x50'

  opts2 := stock.article_options('OPT-001')
  assert jsonb_array_length(opts2) >= 1

  opts3 := stock.article_options('zzz_no_match_zzz')
  assert opts3 = '[]'::jsonb

  stock.article_delete(a->>'id')

test "purchase reception":
  wh := stock.warehouse_create({name: 'Test Workshop', type: 'workshop'})
  a := stock.article_create({reference: 'REC-001', description: 'Douglas 45mm', category: 'wood', unit: 'm3'})

  result := stock.purchase_reception({warehouse_id: (wh->>'id')::int, reception_ref: 'BL-TEST-001', lines: [{article_id: (a->>'id')::int, quantity: 10, unit_price: 420.00}]})
  assert result->>'ok' = 'true'
  assert (result->>'nb_articles')::int = 1

  r := stock.article_read(a->>'id')
  assert (r->>'current_stock')::numeric = 10::numeric
  assert (r->>'wap')::numeric > 0

  stock.article_delete(a->>'id')
  stock.warehouse_delete(wh->>'id')
