test "task crud lifecycle":
  c := plxdemo.task_create({title: 'Buy milk', priority: 'high', done: false})
  assert c->>'title' = 'Buy milk'
  assert c->>'priority' = 'high'
  assert c->>'done' = 'false'

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
