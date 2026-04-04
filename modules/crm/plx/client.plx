entity crm.client uses auditable:
  table: crm.client
  uri: 'crm://client'
  icon: 'U'
  label: 'crm.entity_client'
  list_order: 'updated_at desc'

  fields:
    type text required
    name text required
    email text?
    phone text?
    address text?
    city text?
    postal_code text?
    tier text default('standard')
    notes text? default('')
    active boolean default(true)

  validate:
    type_valid: """
      p_input->>'type' in ('individual', 'company')
    """
    tier_valid: """
      coalesce(p_input->>'tier', 'standard') in ('standard', 'premium', 'vip')
    """

  view:
    compact: [name, type, tier]
    standard:
      fields: [type, email, phone, city, tier]
      stats:
        {key: quote_count, label: crm.stat_quotes}
        {key: total_revenue, label: crm.stat_revenue}
        {key: pending_amount, label: crm.stat_pending}
    expanded:
      fields: [type, email, phone, address, city, postal_code, tier, notes, created_at]
      stats:
        {key: quote_count, label: crm.stat_quotes}
        {key: total_revenue, label: crm.stat_revenue}
        {key: pending_amount, label: crm.stat_pending}
        {key: contact_count, label: crm.col_contacts}
        {key: interaction_count, label: crm.col_interactions}
      related:
        {entity: 'quote://estimate', filter: 'client_id={id}', label: crm.related_quotes}
        {entity: 'quote://invoice', filter: 'client_id={id}', label: crm.related_invoices}
    form:
      'crm.section_identity':
        {key: type, type: select, label: crm.field_type, required: true, options: crm.type_options}
        {key: name, type: text, label: crm.field_name, required: true}
        {key: tier, type: select, label: crm.field_tier, options: crm.tier_options}
      'crm.section_contact':
        {key: email, type: text, label: crm.field_email}
        {key: phone, type: text, label: crm.field_phone}
      'crm.section_address':
        {key: address, type: text, label: crm.field_address}
        {key: city, type: text, label: crm.field_city}
        {key: postal_code, type: text, label: crm.field_postal_code}
      'crm.section_notes':
        {key: notes, type: textarea, label: crm.field_notes}

  actions:
    archive:  {label: crm.action_archive, variant: warning, confirm: crm.confirm_archive}
    activate: {label: crm.action_activate}
    delete:   {label: crm.action_delete, variant: danger, confirm: crm.confirm_delete_client}

fn crm.client_activate(p_id text) -> jsonb [definer]:
  """
    update crm.client set active = true
    where id::text = p_id
      and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(c) from crm.client c where id::text = p_id
  return result

fn crm.client_archive(p_id text) -> jsonb [definer]:
  """
    update crm.client set active = false
    where id::text = p_id
      and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(c) from crm.client c where id::text = p_id
  return result

fn crm.client_options(p_search text?) -> setof jsonb [stable]:
  return """
    select jsonb_build_object(
      'value', c.id::text,
      'label', c.name,
      'detail', concat_ws(' / ', nullif(c.city, ''), nullif(c.email, ''))
    )
    from crm.client c
    where c.active
      and (p_search is null or p_search = ''
           or c.name ilike '%' || p_search || '%'
           or c.email ilike '%' || p_search || '%'
           or c.city ilike '%' || p_search || '%')
    order by c.name
    limit 20
  """
