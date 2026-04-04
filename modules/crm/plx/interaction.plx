entity crm.interaction uses auditable:
  table: crm.interaction
  uri: 'crm://interaction'
  label: 'crm.entity_interaction'
  list_order: 'created_at desc'

  fields:
    client_id int ref(crm.client)
    type text required

  payload:
    subject text required
    body text? default('')

  validate:
    type_valid: """
      p_input->>'type' in ('call', 'visit', 'email', 'note')
    """

  view:
    compact: [subject, type, client_id]
    standard: [type, subject, client_id, created_at]
    expanded: [type, subject, body, client_id, created_at]
    form:
      'crm.section_interaction':
        {key: client_id, type: select, label: crm.col_client, search: true, options: {source: 'crm://client', display: name}, required: true}
        {key: type, type: select, label: crm.field_type, required: true, options: crm.type_options}
        {key: subject, type: text, label: crm.field_subject, required: true}
        {key: body, type: textarea, label: crm.field_details}

  actions:
    delete: {label: crm.action_delete, variant: danger, confirm: crm.confirm_delete_interaction}
