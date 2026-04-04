-- Activate / Deactivate (boolean toggle, not state machine)

fn catalog.article_deactivate(p_id text) -> jsonb [definer]:
  """
    update catalog.article set active = false, updated_at = now()
    where id = p_id::int and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(a) from catalog.article a where id = p_id::int
  return result

fn catalog.article_activate(p_id text) -> jsonb [definer]:
  """
    update catalog.article set active = true, updated_at = now()
    where id = p_id::int and tenant_id = current_setting('app.tenant_id', true)
  """
  result := select to_jsonb(a) from catalog.article a where id = p_id::int
  return result

-- Options functions

fn catalog.unit_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', id::text, 'label', name) order by name)
    from catalog.unit
  """

fn catalog.vat_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v::text, 'label', v || ' %') order by v)
    from (values (0), (2.1), (5.5), (10), (20)) t(v)
  """

-- Article strategies

fn catalog._article_read_query(p_id text) -> jsonb [stable]:
  return """
    select to_jsonb(a) || jsonb_build_object(
      'category_name', c.name,
      'unit_name', u.name,
      'supplier_count', (select count(*) from catalog.supplier_article where article_id = a.id)::int,
      'pricing_tiers', coalesce((
        select jsonb_agg(jsonb_build_object('min_qty', pt.min_qty, 'unit_price', pt.unit_price) order by pt.min_qty)
        from catalog.pricing_tier pt where pt.article_id = a.id
      ), '[]'::jsonb)
    )
    from catalog.article a
    left join catalog.category c on c.id = a.category_id
    left join catalog.unit u on u.id = a.unit_id
    where a.id = p_id::int
      and a.tenant_id = current_setting('app.tenant_id', true)
  """

fn catalog._article_list_query(p_filter text?) -> setof jsonb [stable]:
  return """
    select to_jsonb(a) || jsonb_build_object(
      'category_name', c.name,
      'unit_name', u.name,
      'supplier_count', coalesce(sc.cnt, 0)
    )
    from catalog.article a
    left join catalog.category c on c.id = a.category_id
    left join catalog.unit u on u.id = a.unit_id
    left join lateral (
      select count(*) as cnt from catalog.supplier_article where article_id = a.id
    ) sc on true
    where a.tenant_id = current_setting('app.tenant_id', true)
      and (p_filter is null or p_filter = ''
           or a.name ilike '%' || p_filter || '%'
           or a.reference ilike '%' || p_filter || '%'
           or to_tsvector('french', coalesce(a.name, '')) @@ plainto_tsquery('french', p_filter))
    order by a.name
  """

-- Category strategies

fn catalog._category_read_query(p_id text) -> jsonb [stable]:
  return """
    select to_jsonb(c) || jsonb_build_object(
      'parent_name', p.name,
      'article_count', (select count(*) from catalog.article where category_id = c.id)::int,
      'children_count', (select count(*) from catalog.category where parent_id = c.id)::int
    )
    from catalog.category c
    left join catalog.category p on p.id = c.parent_id
    where c.id = p_id::int
      and c.tenant_id = current_setting('app.tenant_id', true)
  """

fn catalog._category_hateoas(p_result jsonb) -> jsonb [stable]:
  return """
    select case
      when (p_result->>'article_count')::int = 0 and (p_result->>'children_count')::int = 0
      then jsonb_build_array(
        jsonb_build_object('method', 'edit', 'uri', 'catalog://category/' || (p_result->>'id') || '/edit'),
        jsonb_build_object('method', 'delete', 'uri', 'catalog://category/' || (p_result->>'id'))
      )
      else jsonb_build_array(
        jsonb_build_object('method', 'edit', 'uri', 'catalog://category/' || (p_result->>'id') || '/edit')
      )
    end
  """

-- Article options for cross-module use (quote, purchase)

fn catalog.article_options(p_search text?) -> setof jsonb [stable]:
  return """
    select jsonb_build_object(
      'value', a.id::text,
      'label', a.name,
      'detail', concat_ws(' / ', nullif(a.reference, ''), c.name)
    )
    from catalog.article a
    left join catalog.category c on c.id = a.category_id
    where a.active
      and a.tenant_id = current_setting('app.tenant_id', true)
      and (p_search is null or p_search = ''
           or a.name ilike '%' || p_search || '%'
           or a.reference ilike '%' || p_search || '%')
    order by a.name
    limit 20
  """
