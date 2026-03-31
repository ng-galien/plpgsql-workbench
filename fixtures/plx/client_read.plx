fn crm.client_read(p_id int) -> jsonb:
  row := select * from crm.client where id = p_id
    else raise 'not_found'

  actions := []
  if row.status = 'active':
    actions << {action: 'archive'}

  return {data: row, uri: "crm://client/#{row.id}", actions}
