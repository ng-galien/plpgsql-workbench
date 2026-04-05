entity stock.article uses auditable:
  table: stock.article
  uri: 'stock://article'
  icon: 'box'
  label: 'stock.entity_article'
  list_order: 'description'

  fields:
    reference text required
    description text required
    category text required
    unit text default('ea')
    purchase_price numeric?
    wap numeric default(0)
    min_threshold numeric default(0)
    supplier_id int?
    notes text default('')
    active boolean default(true)
    catalog_article_id int?

  validate:
    category_valid: """
      p_input->>'category' in ('wood','hardware','panel','insulation','finish','other')
    """
    unit_valid: """
      coalesce(p_input->>'unit', 'ea') in ('ea','m','m2','m3','kg','l')
    """

  indexes:
    article_ref:
      on: [tenant_id, reference]
      unique: true
    article_category:
      on: [category]
    article_supplier:
      on: [supplier_id]
    article_catalog:
      on: [catalog_article_id]

  view:
    compact: [reference, description, current_stock, unit]
    standard:
      fields: [reference, description, category, unit, supplier_name]
      stats:
        {key: current_stock, label: stock.stat_stock_total}
        {key: wap, label: stock.stat_pmp}
        {key: min_threshold, label: stock.stat_min_threshold}
      related:
        {entity: 'crm://client', filter: 'id={supplier_id}', label: stock.rel_supplier}
    expanded:
      fields: [reference, description, category, unit, purchase_price, wap, min_threshold, supplier_name, notes, active, created_at, updated_at]
      stats:
        {key: current_stock, label: stock.stat_stock_total}
        {key: wap, label: stock.stat_pmp}
        {key: min_threshold, label: stock.stat_min_threshold}
      related:
        {entity: 'crm://client', filter: 'id={supplier_id}', label: stock.rel_supplier}
        {entity: 'catalog://article', filter: 'id={catalog_article_id}', label: stock.rel_catalog}
    form:
      'stock.section_identity':
        {key: reference, type: text, label: stock.field_reference, required: true}
        {key: description, type: text, label: stock.field_description, required: true}
        {key: category, type: select, label: stock.field_category, required: true, options: stock.category_options}
        {key: unit, type: select, label: stock.field_unit, required: true, options: stock.unit_options}
      'stock.section_pricing':
        {key: purchase_price, type: number, label: stock.field_purchase_price}
        {key: min_threshold, type: number, label: stock.field_min_threshold}
      'stock.section_links':
        {key: supplier_id, type: select, label: stock.field_supplier, search: true, options: {source: 'crm://client', display: name, filter: 'type=company;active=true'}}
        {key: catalog_article_id, type: select, label: stock.field_catalog_article, search: true, options: {source: 'catalog://article', display: description}}
        {key: notes, type: textarea, label: stock.field_notes}

  strategies:
    read.query: stock._article_read_query
    read.hateoas: stock._article_hateoas
    list.query: stock._article_list_query

  actions:
    edit:       {label: stock.action_edit, variant: muted}
    deactivate: {label: stock.action_deactivate, variant: warning, confirm: stock.confirm_deactivate}
    activate:   {label: stock.action_activate, variant: primary}
    delete:     {label: stock.action_delete, variant: danger, confirm: stock.confirm_delete}

fn stock._article_read_query(p_id text) -> jsonb [stable]:
  return """
    select to_jsonb(a) || jsonb_build_object(
      'supplier_name', c.name,
      'current_stock', stock._current_stock(a.id, NULL::int)
    )
    from stock.article a
    left join crm.client c on c.id = a.supplier_id
    where a.id = p_id::int
      and a.tenant_id = current_setting('app.tenant_id', true)
  """

fn stock._article_hateoas(p_result jsonb) -> jsonb [stable]:
  return """
    select case (p_result->>'active')::boolean
      when true then jsonb_build_array(
        jsonb_build_object('method', 'edit',       'uri', 'stock://article/' || (p_result->>'id') || '/edit'),
        jsonb_build_object('method', 'deactivate', 'uri', 'stock://article/' || (p_result->>'id') || '/deactivate'),
        jsonb_build_object('method', 'delete',     'uri', 'stock://article/' || (p_result->>'id'))
      )
      else jsonb_build_array(
        jsonb_build_object('method', 'activate', 'uri', 'stock://article/' || (p_result->>'id') || '/activate'),
        jsonb_build_object('method', 'delete',   'uri', 'stock://article/' || (p_result->>'id'))
      )
    end
  """

fn stock._article_list_query(p_filter text?) -> setof jsonb [stable]:
  return """
    select to_jsonb(a) || jsonb_build_object(
      'supplier_name', c.name,
      'current_stock', stock._current_stock(a.id, NULL::int)
    )
    from stock.article a
    left join crm.client c on c.id = a.supplier_id
    where a.tenant_id = current_setting('app.tenant_id', true)
      and (p_filter is null or p_filter = ''
           or a.description ilike '%' || p_filter || '%'
           or a.reference ilike '%' || p_filter || '%'
           or a.category = p_filter)
    order by a.description
  """

fn stock.article_activate(p_id text) -> jsonb [definer]:
  """
    update stock.article set active = true
    where id = p_id::int
      and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(a) from stock.article a where id = p_id::int
  return result

fn stock.article_deactivate(p_id text) -> jsonb [definer]:
  """
    update stock.article set active = false
    where id = p_id::int
      and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(a) from stock.article a where id = p_id::int
  return result

fn stock.article_options(p_search text?) -> jsonb [stable]:
  return """
    select coalesce(jsonb_agg(r order by r->>'label'), '[]'::jsonb)
    from (
      select jsonb_build_object(
        'value', a.id::text,
        'label', a.description,
        'detail', a.reference || ' — ' || a.category || ' (' || a.unit || ')'
      ) as r
      from stock.article a
      where a.active
        and (p_search is null or p_search = ''
             or a.description ilike '%' || p_search || '%'
             or a.reference ilike '%' || p_search || '%')
      order by a.description
      limit 20
    ) sub
  """
