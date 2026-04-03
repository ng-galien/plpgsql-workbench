test "project crud lifecycle":
  c := plxdemo.project_create({name: 'Alpha', code: 'ALPHA', description: 'First project', budget: 10000})
  assert c->>'name' = 'Alpha'
  assert c->>'code' = 'ALPHA'
  assert c->>'status' = 'draft'
  assert (c->>'budget')::numeric = 10000::numeric

  r := plxdemo.project_read(c->>'id')
  assert r->>'name' = 'Alpha'
  assert r->>'actions' != 'null'

  u := plxdemo.project_update(c->>'id', {description: 'Updated desc'})
  assert u->>'description' = 'Updated desc'
  assert u->>'code' = 'ALPHA'

  d := plxdemo.project_delete(c->>'id')
  assert d->>'name' = 'Alpha'

test "project state transitions":
  c := plxdemo.project_create({name: 'Beta', code: 'BETA'})
  assert c->>'status' = 'draft'

  blocked := false
  try:
    plxdemo.project_activate(c->>'id')
  catch:
    blocked := true
  assert blocked = true

  u := plxdemo.project_update(c->>'id', {budget: 5000, owner: 'Alice'})
  assert (u->>'budget')::numeric = 5000::numeric
  assert u->>'owner' = 'Alice'

  a := plxdemo.project_activate(c->>'id')
  assert a->>'status' = 'active'

  kickoff_count := select count(*) from plxdemo.task where project_id = (v_a->>'id')::int and payload->>'title' = 'Kickoff'
  assert kickoff_count = 1::bigint

  co := plxdemo.project_complete(c->>'id')
  assert co->>'status' = 'completed'

  ar := plxdemo.project_archive(c->>'id')
  assert ar->>'status' = 'archived'

test "project soft delete hides from read":
  c := plxdemo.project_create({name: 'Soft', code: 'SOFTDEL'})
  plxdemo.project_delete(c->>'id')
  r := plxdemo.project_read(c->>'id')
  assert r is null

test "project list":
  plxdemo.project_create({name: 'Listed1', code: 'L1'})
  plxdemo.project_create({name: 'Listed2', code: 'L2'})
  n := select count(*) from plxdemo.project_list()
  assert n >= 2

test "project rejects negative budget":
  blocked := false
  try:
    plxdemo.project_create({name: 'Invalid', code: 'INVALID', budget: -1})
  catch:
    blocked := true
  assert blocked = true
