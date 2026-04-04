fn asset.mime_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values
      ('image/jpeg',    'asset.mime_jpeg',    1),
      ('image/png',     'asset.mime_png',     2),
      ('image/svg+xml', 'asset.mime_svg',     3)
    ) t(v, l, o)
  """

fn asset.season_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values
      ('spring', 'asset.season_spring', 1),
      ('summer', 'asset.season_summer', 2),
      ('autumn', 'asset.season_autumn', 3),
      ('winter', 'asset.season_winter', 4)
    ) t(v, l, o)
  """

fn asset.orientation_options() -> jsonb [stable]:
  return """
    select jsonb_agg(jsonb_build_object('value', v, 'label', l) order by o)
    from (values
      ('landscape', 'asset.orientation_landscape', 1),
      ('portrait',  'asset.orientation_portrait',  2),
      ('square',    'asset.orientation_square',     3)
    ) t(v, l, o)
  """

fn asset.classify(p_id int, p_title text, p_description text?, p_tags text[]?, p_width int?, p_height int?, p_orientation text?, p_season text?, p_credit text?, p_usage_hint text?, p_colors text[]?) -> jsonb [definer]:
  if p_title is null or trim(p_title) = '':
    raise 'asset.err_title_required'
  found := """
    update asset.asset set
      title         = trim(p_title),
      description   = nullif(trim(coalesce(p_description, '')), ''),
      tags          = coalesce(p_tags, '{}'),
      width         = p_width,
      height        = p_height,
      orientation   = p_orientation,
      season        = p_season,
      credit        = nullif(trim(coalesce(p_credit, '')), ''),
      usage_hint    = nullif(trim(coalesce(p_usage_hint, '')), ''),
      colors        = coalesce(p_colors, '{}'),
      status        = 'classified',
      classified_at = now()
    where id = p_id
    returning true
  """
  if found is null:
    raise 'asset.err_not_found'
  return {id: p_id, status: 'classified'}

fn asset.search(p_params jsonb?) -> jsonb [stable]:
  return """
    with params as (
      select
        nullif(trim(coalesce(p_params->>'p_status', '')), '') as status,
        case when p_params ? 'p_tags' and p_params->>'p_tags' is not null
          then array(select jsonb_array_elements_text(p_params->'p_tags'))
          else null end as tags,
        nullif(trim(coalesce(p_params->>'q', '')), '') as q,
        nullif(trim(coalesce(p_params->>'p_mime', '')), '') as mime,
        coalesce((p_params->>'_offset')::int, 0) as off,
        coalesce((p_params->>'_size')::int, 20) as sz
    ),
    matched as (
      select a.id, a.filename, a.path, a.mime_type, a.status,
             a.title, a.description, a.tags, a.width, a.height,
             a.orientation, a.season, a.credit, a.usage_hint, a.colors,
             a.created_at, a.classified_at
      from asset.asset a, params p
      where (p.status is null or a.status = p.status)
        and (p.tags is null or a.tags && p.tags)
        and (p.q is null or a.search_vec @@ plainto_tsquery('simple', p.q))
        and (p.mime is null or a.mime_type ilike p.mime || '%')
      order by a.created_at desc
      limit (select sz + 1 from params) offset (select off from params)
    )
    select jsonb_build_object(
      'rows', coalesce((select jsonb_agg(to_jsonb(r)) from (select * from matched limit (select sz from params)) r), '[]'),
      'has_more', (select count(*) from matched) > (select sz from params)
    )
  """

fn asset.data_assets(p_params jsonb?) -> jsonb [stable]:
  return """
    with params as (
      select
        nullif(trim(coalesce(p_params->>'p_status', '')), '') as status,
        nullif(trim(coalesce(p_params->>'q', '')), '') as q,
        coalesce((p_params->>'_offset')::int, 0) as off,
        coalesce((p_params->>'_size')::int, 20) as sz
    ),
    matched as (
      select jsonb_build_array(
        a.id, a.filename, coalesce(a.title, '—'), a.mime_type, a.status,
        coalesce(array_to_string(a.tags, ', '), ''),
        to_char(a.created_at, 'DD/MM/YYYY')
      ) as row
      from asset.asset a, params p
      where (p.status is null or a.status = p.status)
        and (p.q is null or a.search_vec @@ plainto_tsquery('simple', p.q))
      order by a.created_at desc
      limit (select sz + 1 from params) offset (select off from params)
    )
    select jsonb_build_object(
      'rows', coalesce((select jsonb_agg(r.row) from (select * from matched limit (select sz from params)) r), '[]'),
      'has_more', (select count(*) from matched) > (select sz from params)
    )
  """
