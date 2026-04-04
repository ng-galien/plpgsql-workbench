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
