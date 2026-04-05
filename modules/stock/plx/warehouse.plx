entity stock.warehouse uses auditable:
  table: stock.warehouse
  uri: 'stock://warehouse'
  icon: 'warehouse'
  label: 'stock.entity_warehouse'
  list_order: 'name'

  fields:
    name text required
    type text required
    address text?
    active boolean default(true)

  validate:
    type_valid: """
      p_input->>'type' in ('workshop','job_site','vehicle','storage')
    """

  indexes:
    warehouse_tenant:
      on: [tenant_id]

  view:
    compact: [name, type, article_count]
    standard:
      fields: [name, type, address, active]
      stats:
        {key: article_count, label: stock.stat_nb_articles}
      related:
        {entity: 'stock://article', filter: 'warehouse_id={id}', label: stock.rel_articles}
    expanded:
      fields: [name, type, address, active, created_at]
      stats:
        {key: article_count, label: stock.stat_nb_articles}
      related:
        {entity: 'stock://article', filter: 'warehouse_id={id}', label: stock.rel_articles}
    form:
      'stock.section_identity':
        {key: name, type: text, label: stock.field_name, required: true}
        {key: type, type: select, label: stock.field_type, required: true, options: stock.warehouse_type_options}
      'stock.section_location':
        {key: address, type: text, label: stock.field_address}

  strategies:
    read.query: stock._warehouse_read_query
    read.hateoas: stock._warehouse_hateoas
    list.query: stock._warehouse_list_query

  actions:
    edit:       {label: stock.action_edit, variant: muted}
    deactivate: {label: stock.action_deactivate, variant: warning, confirm: stock.confirm_deactivate}
    activate:   {label: stock.action_activate, variant: primary}
    inventory:  {label: stock.action_inventory, variant: default}
    delete:     {label: stock.action_delete, variant: danger, confirm: stock.confirm_delete}

fn stock._warehouse_read_query(p_id text) -> jsonb [stable]:
  return """
    select to_jsonb(w) || jsonb_build_object(
      'article_count', (
        select count(distinct m.article_id)::int
        from stock.movement m
        where m.warehouse_id = w.id
      )
    )
    from stock.warehouse w
    where w.id = p_id::int
      and w.tenant_id = current_setting('app.tenant_id', true)
  """

fn stock._warehouse_hateoas(p_result jsonb) -> jsonb [stable]:
  return """
    select case (p_result->>'active')::boolean
      when true then jsonb_build_array(
        jsonb_build_object('method', 'edit',       'uri', 'stock://warehouse/' || (p_result->>'id') || '/edit'),
        jsonb_build_object('method', 'deactivate', 'uri', 'stock://warehouse/' || (p_result->>'id') || '/deactivate'),
        jsonb_build_object('method', 'inventory',  'uri', 'stock://warehouse/' || (p_result->>'id') || '/inventory'),
        jsonb_build_object('method', 'delete',     'uri', 'stock://warehouse/' || (p_result->>'id'))
      )
      else jsonb_build_array(
        jsonb_build_object('method', 'activate', 'uri', 'stock://warehouse/' || (p_result->>'id') || '/activate'),
        jsonb_build_object('method', 'delete',   'uri', 'stock://warehouse/' || (p_result->>'id'))
      )
    end
  """

fn stock._warehouse_list_query(p_filter text?) -> setof jsonb [stable]:
  return """
    select to_jsonb(w) || jsonb_build_object(
      'article_count', (
        select count(distinct m.article_id)::int
        from stock.movement m
        where m.warehouse_id = w.id
      )
    )
    from stock.warehouse w
    where w.tenant_id = current_setting('app.tenant_id', true)
      and (p_filter is null or p_filter = ''
           or w.name ilike '%' || p_filter || '%'
           or w.type = p_filter)
    order by w.name
  """

fn stock.warehouse_activate(p_id text) -> jsonb [definer]:
  """
    update stock.warehouse set active = true
    where id = p_id::int
      and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(w) from stock.warehouse w where id = p_id::int
  return result

fn stock.warehouse_deactivate(p_id text) -> jsonb [definer]:
  """
    update stock.warehouse set active = false
    where id = p_id::int
      and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(w) from stock.warehouse w where id = p_id::int
  return result

fn stock.warehouse_options(p_search text?) -> setof jsonb [stable]:
  return """
    select jsonb_build_object(
      'value', w.id::text,
      'label', w.name,
      'detail', w.type
    )
    from stock.warehouse w
    where w.active
      and (p_search is null or p_search = ''
           or w.name ilike '%' || p_search || '%')
    order by w.name
    limit 20
  """
