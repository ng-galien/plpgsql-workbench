-- Test: schema-qualified calls, setof, for..in, match, SQL escaping, INSERT RETURNING

fn crm.client_search(p_query text) -> setof jsonb:
  for row in select * from crm.client where name ilike '%' || p_query || '%' order by name:
    yield {id: row.id, name: row.name, email: row.email}

fn crm.client_create(p_data jsonb) -> jsonb:
  result := insert into crm.client (name, email)
    values (p_data->>'name', p_data->>'email')
    returning *
  slug := crm.slugify(result.name)
  return {data: result, uri: "crm://client/#{result.id}", slug}

fn crm.client_status_label(p_status text) -> text:
  match p_status:
    'draft' ->
      return 'Brouillon'
    'active' ->
      return 'Actif'
    else:
      return 'Inconnu'

fn crm.client_greet(p_id int) -> text:
  name := select name from crm.client where id = p_id
    else raise 'client doesn''t exist'
  msg := "Bonjour #{name}, bienvenue chez l'entreprise"
  return msg
