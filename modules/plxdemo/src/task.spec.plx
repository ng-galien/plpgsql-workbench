test "task crud lifecycle":
  n := plxdemo.note_create({title: 'Linked note', body: 'Task dependency'})
  p := plxdemo.project_create({name: 'TaskProj', code: 'TP'})
  c := plxdemo.task_create({title: 'Buy milk', priority: 'high', done: false, rank: 3, note_id: (n->>'id')::int, project_id: (p->>'id')::int})
  assert c->>'title' = 'Buy milk'
  assert c->>'priority' = 'high'
  assert c->>'done' = 'false'
  assert c->>'rank' = '3'
  assert c->>'note_id' = n->>'id'
  assert c->>'project_id' = p->>'id'

  r := plxdemo.task_read(c->>'id')
  assert r->>'title' = 'Buy milk'
  assert r->>'actions' != 'null'

  u := plxdemo.task_update(c->>'id', {title: 'Buy oat milk'})
  assert u->>'title' = 'Buy oat milk'

  d := plxdemo.task_delete(c->>'id')
  assert d->>'title' = 'Buy oat milk'

test "task list":
  plxdemo.task_create({title: 'Alpha', priority: 'normal', done: false})
  plxdemo.task_create({title: 'Beta', priority: 'low', done: true})
  n := select count(*) from plxdemo.task_list()
  assert n >= 2

test "task rejects invalid priority":
  blocked := false
  try:
    plxdemo.task_create({title: 'Broken', priority: 'urgent'})
  catch:
    blocked := true
  assert blocked = true
