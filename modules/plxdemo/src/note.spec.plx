test "note crud lifecycle":
  c := plxdemo.note_create({title: 'Draft note', body: 'Hello'})
  assert c->>'title' = 'Draft note'
  assert c->>'body' = 'Hello'

  r := plxdemo.note_read(c->>'id')
  assert r->>'title' = 'Draft note'
  assert r->>'actions' != 'null'

  u := plxdemo.note_update(c->>'id', {title: 'Updated note'})
  assert u->>'title' = 'Updated note'

  d := plxdemo.note_delete(c->>'id')
  assert d->>'title' = 'Updated note'
