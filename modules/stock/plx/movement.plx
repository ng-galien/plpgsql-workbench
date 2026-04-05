entity stock.movement:
  table: stock.movement
  uri: 'stock://movement'
  expose: false

  fields:
    article_id int required ref(stock.article)
    warehouse_id int required ref(stock.warehouse)
    type text required
    quantity numeric required
    unit_price numeric?
    reference text?
    destination_warehouse_id int? ref(stock.warehouse)
    notes text default('')
    created_at timestamptz default(now())

  indexes:
    movement_article:
      on: [article_id]
    movement_warehouse:
      on: [warehouse_id]
    movement_date:
      on: [created_at desc]

fn stock.purchase_reception(p_data jsonb) -> jsonb [definer]:
  wh_count int := 0
  nb int := 0

  wh_count := select count(*)::int
              from stock.warehouse
              where id = (p_data->>'warehouse_id')::int
                and active = true

  if wh_count = 0:
    return jsonb_build_object('ok', false, 'error', i18n.t('stock.err_warehouse_inactive'))

  if jsonb_array_length(coalesce(p_data->'lines', '[]'::jsonb)) = 0:
    return jsonb_build_object('ok', false, 'error', i18n.t('stock.err_no_lines'))

  """
    insert into stock.movement (article_id, warehouse_id, type, quantity, unit_price, reference, tenant_id)
    select (l->>'article_id')::int,
           (p_data->>'warehouse_id')::int,
           'entry',
           (l->>'quantity')::numeric,
           nullif(l->>'unit_price', '')::numeric,
           coalesce(p_data->>'reception_ref', 'RECEPTION'),
           current_setting('app.tenant_id', true)
    from jsonb_array_elements(p_data->'lines') l
    join stock.article a on a.id = (l->>'article_id')::int and a.active
    where (l->>'quantity')::numeric > 0
  """

  """
    update stock.article a
    set purchase_price = nullif(l->>'unit_price', '')::numeric
    from jsonb_array_elements(p_data->'lines') l
    where a.id = (l->>'article_id')::int
      and nullif(l->>'unit_price', '') is not null
  """

  """
    update stock.article a
    set wap = coalesce((
      select sum(m.quantity * m.unit_price) / nullif(sum(m.quantity), 0)
      from stock.movement m
      where m.article_id = a.id and m.type = 'entry' and m.unit_price is not null
    ), 0)
    where a.id = any(
      array(
        select distinct (l->>'article_id')::int
        from jsonb_array_elements(p_data->'lines') l
        join stock.article x on x.id = (l->>'article_id')::int and x.active
        where (l->>'quantity')::numeric > 0
      )
    )
  """

  nb := select count(distinct (l->>'article_id')::int)::int
        from jsonb_array_elements(p_data->'lines') l
        join stock.article a on a.id = (l->>'article_id')::int and a.active
        where (l->>'quantity')::numeric > 0

  return jsonb_build_object(
    'ok', true,
    'nb_articles', nb,
    'warehouse_id', (p_data->>'warehouse_id')::integer,
    'reference', coalesce(p_data->>'reception_ref', 'RECEPTION')
  )
