fn stock._current_stock(p_article_id int, p_warehouse_id int?) -> numeric [stable]:
  return """
    select coalesce(sum(quantity), 0)
    from stock.movement
    where article_id = p_article_id
      and (p_warehouse_id is null or warehouse_id = p_warehouse_id)
  """

fn stock._recalc_wap(p_article_id int) -> void [definer]:
  """
    update stock.article
    set wap = coalesce((
      select sum(quantity * unit_price) / nullif(sum(quantity), 0)
      from stock.movement
      where article_id = p_article_id and type = 'entry' and unit_price is not null
    ), 0)
    where id = p_article_id
  """

fn stock.category_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values
      ('wood',       'stock.cat_wood',       1),
      ('hardware',   'stock.cat_hardware',   2),
      ('panel',      'stock.cat_panel',      3),
      ('insulation', 'stock.cat_insulation', 4),
      ('finish',     'stock.cat_finishing',  5),
      ('other',      'stock.cat_other',      6)
    ) t(v, l, o)
  """

fn stock.unit_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values
      ('ea', 'stock.unit_u',  1),
      ('m',  'stock.unit_m',  2),
      ('m2', 'stock.unit_m2', 3),
      ('m3', 'stock.unit_m3', 4),
      ('kg', 'stock.unit_kg', 5),
      ('l',  'stock.unit_l',  6)
    ) t(v, l, o)
  """

fn stock._test_cleanup(p_article_id text?) -> void [definer]:
  if p_article_id is not null:
    """
      delete from stock.movement where article_id = p_article_id::int
    """
    """
      delete from stock.article where id = p_article_id::int and tenant_id = current_setting('app.tenant_id', true)
    """

fn stock.warehouse_type_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values
      ('workshop', 'stock.warehouse_workshop', 1),
      ('job_site', 'stock.warehouse_site',     2),
      ('vehicle',  'stock.warehouse_vehicle',  3),
      ('storage',  'stock.warehouse_storage',  4)
    ) t(v, l, o)
  """
