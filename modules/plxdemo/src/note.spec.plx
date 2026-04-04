test "note crud lifecycle":
  c := plxdemo.note_create({title: 'Draft note', body: 'Hello'})
  assert c->>'title' = 'Draft note'
  assert c->>'body' = 'Hello'

  r := plxdemo.note_read(c->>'id')
  assert r->>'title' = 'Draft note'
  assert r->>'actions' != 'null'

  u := plxdemo.note_update(c->>'id', {title: 'Updated note', pinned: true})
  assert u->>'title' = 'Updated note'

  d := plxdemo.note_delete(c->>'id')
  assert d->>'title' = 'Updated note'

test "note soft delete hides from list":
  c := plxdemo.note_create({title: 'Vanish'})
  plxdemo.note_delete(c->>'id')
  r := plxdemo.note_read(c->>'id')
  assert r is null

test "module i18n sidecar seeds translations":
  plxdemo.i18n_seed()
  lang := set_config('pgv.lang', 'fr', true)
  assert lang = 'fr'
  assert pgv.t('plxdemo.entity_task') = 'Tâche'
  assert pgv.t('plxdemo.field_priority') = 'Priorité'
  assert pgv.t('plxdemo.confirm_delete') = 'Supprimer cet élément ?'
