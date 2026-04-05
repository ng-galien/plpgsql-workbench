test "article crud":
  a := catalog.article_create({name: 'Chêne massif', reference: 'BOIS-001', sale_price: 120, purchase_price: 80})
  assert a->>'name' = 'Chêne massif'
  assert a->>'reference' = 'BOIS-001'
  assert (a->>'sale_price')::numeric = 120::numeric
  assert (a->>'active')::boolean = true

  r := catalog.article_read(a->>'id')
  assert r->>'name' = 'Chêne massif'

  u := catalog.article_update(a->>'id', {sale_price: 130})
  assert (u->>'sale_price')::numeric = 130::numeric

  d := catalog.article_delete(a->>'id')
  assert d->>'name' = 'Chêne massif'

test "article validation rejects invalid vat":
  blocked := false
  try:
    catalog.article_create({name: 'Bad VAT', vat_rate: 15})
  catch:
    blocked := true
  assert blocked = true

test "article deactivate and activate":
  a := catalog.article_create({name: 'Toggle Test', reference: 'TOG-001'})
  assert (a->>'active')::boolean = true

  catalog.article_deactivate(a->>'id')
  r1 := catalog.article_read(a->>'id')
  assert (r1->>'active')::boolean = false

  catalog.article_activate(a->>'id')
  r2 := catalog.article_read(a->>'id')
  assert (r2->>'active')::boolean = true

  catalog.article_delete(a->>'id')

test "article hateoas reflects active state":
  a := catalog.article_create({name: 'Hateoas Test', reference: 'HAT-001'})

  r1 := catalog.article_read(a->>'id')
  actions1 := r1->'actions'
  assert jsonb_path_exists(actions1, '$[*] ? (@.method == "deactivate")')
  assert jsonb_path_exists(actions1, '$[*] ? (@.method == "edit")')
  assert jsonb_path_exists(actions1, '$[*] ? (@.method == "delete")')

  catalog.article_deactivate(a->>'id')
  r2 := catalog.article_read(a->>'id')
  actions2 := r2->'actions'
  assert jsonb_path_exists(actions2, '$[*] ? (@.method == "activate")')

  catalog.article_delete(a->>'id')

test "article list enriched":
  cat := catalog.category_create({name: 'List Cat'})
  a := catalog.article_create({name: 'Enriched Article', reference: 'ENR-001', category_id: (cat->>'id')::int})

  row := """
    select to_jsonb(r) from catalog._article_list_query(null) r
    where r->>'id' = v_a->>'id'
    limit 1
  """
  assert row->>'category_name' = 'List Cat'
  assert (row->>'supplier_count')::int >= 0

  catalog.article_delete(a->>'id')
  catalog.category_delete(cat->>'id')

test "supplier article crud":
  a := catalog.article_create({name: 'Supplier Test', reference: 'SUP-001'})
  s := catalog.supplier_article_create({article_id: (a->>'id')::int, supplier_name: 'Leroy Merlin', cost_price: 50.00, lead_time_days: 5})
  assert s->>'supplier_name' = 'Leroy Merlin'

  catalog.supplier_article_delete(s->>'id')
  catalog.article_delete(a->>'id')

test "pricing tier in article read":
  a := catalog.article_create({name: 'Tier Test', reference: 'TIER-001', sale_price: 100})
  """
    insert into catalog.pricing_tier (tenant_id, article_id, min_qty, unit_price) values
    (current_setting('app.tenant_id'), (v_a->>'id')::int, 10, 90),
    (current_setting('app.tenant_id'), (v_a->>'id')::int, 50, 80)
  """
  r := catalog.article_read(a->>'id')
  assert jsonb_array_length(r->'pricing_tiers') = 2

  """
    delete from catalog.pricing_tier where article_id = (v_a->>'id')::int
  """
  catalog.article_delete(a->>'id')
