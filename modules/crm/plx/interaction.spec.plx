test "interaction crud lifecycle":
  c := crm.client_create({type: 'company', name: 'InterCorp'})
  i := crm.interaction_create({client_id: (c->>'id')::int, type: 'call', subject: 'Premier contact', body: 'RDV confirmé'})
  assert i->>'subject' = 'Premier contact'
  assert i->>'type' = 'call'
  assert i->>'body' = 'RDV confirmé'

  r := crm.interaction_read(i->>'id')
  assert r->>'subject' = 'Premier contact'
  assert r->>'actions' != 'null'

  d := crm.interaction_delete(i->>'id')
  assert d->>'subject' = 'Premier contact'

test "interaction validation rejects invalid type":
  c := crm.client_create({type: 'company', name: 'TypeCorp'})
  blocked := false
  try:
    crm.interaction_create({client_id: (c->>'id')::int, type: 'meeting', subject: 'Bad'})
  catch:
    blocked := true
  assert blocked = true

test "interaction list":
  c := crm.client_create({type: 'individual', name: 'ListClient'})
  crm.interaction_create({client_id: (c->>'id')::int, type: 'note', subject: 'Note 1'})
  crm.interaction_create({client_id: (c->>'id')::int, type: 'email', subject: 'Email 1'})
  n := select count(*) from crm.interaction_list()
  assert n >= 2
