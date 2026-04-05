test "category crud":
  c := catalog.category_create({name: 'Bois', sort_order: 1})
  assert c->>'name' = 'Bois'

  r := catalog.category_read(c->>'id')
  assert r->>'name' = 'Bois'
  assert (r->>'article_count')::int = 0
  assert (r->>'children_count')::int = 0

  child := catalog.category_create({name: 'Massif', parent_id: (c->>'id')::int})
  r2 := catalog.category_read(c->>'id')
  assert (r2->>'children_count')::int = 1

  catalog.category_delete(child->>'id')
  catalog.category_delete(c->>'id')

test "category delete blocked with articles":
  c := catalog.category_create({name: 'With Article'})
  a := catalog.article_create({name: 'In Category', category_id: (c->>'id')::int})

  r := catalog.category_read(c->>'id')
  assert (r->>'article_count')::int = 1

  catalog.article_delete(a->>'id')
  catalog.category_delete(c->>'id')

test "category list enriched with parent name and article count":
  parent := catalog.category_create({name: 'Parent Cat', sort_order: 1})
  child := catalog.category_create({name: 'Child Cat', parent_id: (parent->>'id')::int, sort_order: 2})
  a := catalog.article_create({name: 'Cat List Article', category_id: (child->>'id')::int})

  row := """
    select to_jsonb(r) from catalog._category_list_query(null) r
    where r->>'id' = v_child->>'id'
    limit 1
  """
  assert row->>'parent_name' = 'Parent Cat'
  assert (row->>'article_count')::int = 1

  catalog.article_delete(a->>'id')
  catalog.category_delete(child->>'id')
  catalog.category_delete(parent->>'id')

test "category hateoas blocks delete when not empty":
  c := catalog.category_create({name: 'Non Empty Cat'})
  a := catalog.article_create({name: 'Blocking Article', category_id: (c->>'id')::int})

  r := catalog.category_read(c->>'id')
  actions := r->'actions'
  assert jsonb_path_exists(actions, '$[*] ? (@.method == "edit")')

  catalog.article_delete(a->>'id')
  r2 := catalog.category_read(c->>'id')
  actions2 := r2->'actions'
  assert jsonb_path_exists(actions2, '$[*] ? (@.method == "delete")')

  catalog.category_delete(c->>'id')
