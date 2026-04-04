test "client crud lifecycle":
  c := crm.client_create({type: 'company', name: 'Acme Corp', email: 'contact@acme.com', tier: 'standard'})
  assert c->>'name' = 'Acme Corp'
  assert c->>'type' = 'company'
  assert c->>'tier' = 'standard'
  assert (c->>'active')::boolean = true

  r := crm.client_read(c->>'id')
  assert r->>'name' = 'Acme Corp'
  assert r->>'actions' != 'null'

  u := crm.client_update(c->>'id', {email: 'new@acme.com', city: 'Paris'})
  assert u->>'email' = 'new@acme.com'
  assert u->>'city' = 'Paris'
  assert u->>'name' = 'Acme Corp'

  d := crm.client_delete(c->>'id')
  assert d->>'name' = 'Acme Corp'

test "client activate and archive":
  c := crm.client_create({type: 'individual', name: 'Jean Dupont'})
  assert (c->>'active')::boolean = true

  a := crm.client_archive(c->>'id')
  assert (a->>'active')::boolean = false

  r := crm.client_activate(c->>'id')
  assert (r->>'active')::boolean = true

test "client validation rejects invalid type":
  blocked := false
  try:
    crm.client_create({type: 'unknown', name: 'Bad'})
  catch:
    blocked := true
  assert blocked = true

test "client validation rejects invalid tier":
  blocked := false
  try:
    crm.client_create({type: 'individual', name: 'Bad', tier: 'gold'})
  catch:
    blocked := true
  assert blocked = true

test "client list":
  crm.client_create({type: 'company', name: 'Alpha SA'})
  crm.client_create({type: 'individual', name: 'Beta Dupont'})
  n := select count(*) from crm.client_list()
  assert n >= 2

test "client options search":
  crm.client_create({type: 'company', name: 'SearchCorp', city: 'Lyon'})
  n := select count(*) from crm.client_options('SearchCorp')
  assert n >= 1
