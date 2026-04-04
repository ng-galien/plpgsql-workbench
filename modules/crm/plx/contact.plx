entity crm.contact:
  table: crm.contact
  uri: 'crm://contact'
  label: 'crm.entity_contact'
  list_order: 'is_primary desc'

  fields:
    client_id int ref(crm.client)
    is_primary boolean default(false)

  payload:
    name text required
    role text? default('')
    email text?
    phone text?

  actions:
    delete: {label: crm.action_delete, variant: danger, confirm: crm.confirm_delete_contact}
