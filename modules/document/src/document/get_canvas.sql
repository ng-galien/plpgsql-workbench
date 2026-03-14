CREATE OR REPLACE FUNCTION document.get_canvas(p_id uuid)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c document.canvas;
  v_body text;
  v_svg text;
  v_elem_cnt int;
  v_rows text[];
  v_indent text;
  v_pos text;
  v_dims text;
  r record;
BEGIN
  SELECT * INTO v_c FROM document.canvas WHERE id = p_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_c IS NULL THEN
    RETURN pgv.empty('Canvas introuvable');
  END IF;

  SELECT count(*)::int INTO v_elem_cnt FROM document.element WHERE canvas_id = p_id;

  -- Breadcrumb
  v_body := pgv.breadcrumb(VARIADIC ARRAY['Documents', '/', v_c.name]);

  -- Info line
  v_body := v_body || '<p><small>'
    || v_c.format || ' ' || v_c.orientation
    || ' · ' || v_c.width::int::text || '×' || v_c.height::int::text || 'mm'
    || ' · ' || v_elem_cnt::text || ' éléments'
    || ' · ' || pgv.esc(v_c.category)
    || '</small></p>';

  -- SVG canvas
  v_svg := document.canvas_render_svg_mini(p_id);
  IF v_svg IS NOT NULL THEN
    v_body := v_body || pgv.svg_canvas(v_svg, '{"height":"70vh"}'::jsonb);
  END IF;

  -- Element table
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT e.sort_order, e.type, e.name, e.parent_id,
           e.x, e.y, e.width, e.height,
           e.x1, e.y1, e.x2, e.y2,
           e.cx, e.cy, e.r, e.rx_, e.ry_,
           e.fill
    FROM document.element e
    WHERE e.canvas_id = p_id
    ORDER BY e.sort_order
  LOOP
    v_indent := CASE WHEN r.parent_id IS NOT NULL THEN '└─ ' ELSE '' END;

    v_pos := CASE r.type
      WHEN 'text' THEN COALESCE(r.x::int::text, '') || ',' || COALESCE(r.y::int::text, '')
      WHEN 'rect' THEN COALESCE(r.x::int::text, '') || ',' || COALESCE(r.y::int::text, '')
      WHEN 'image' THEN COALESCE(r.x::int::text, '') || ',' || COALESCE(r.y::int::text, '')
      WHEN 'line' THEN COALESCE(r.x1::int::text, '') || ',' || COALESCE(r.y1::int::text, '') || '->' || COALESCE(r.x2::int::text, '') || ',' || COALESCE(r.y2::int::text, '')
      WHEN 'circle' THEN COALESCE(r.cx::int::text, '') || ',' || COALESCE(r.cy::int::text, '')
      WHEN 'ellipse' THEN COALESCE(r.cx::int::text, '') || ',' || COALESCE(r.cy::int::text, '')
      ELSE '—'
    END;

    v_dims := CASE r.type
      WHEN 'rect' THEN COALESCE(r.width::int::text, '') || '×' || COALESCE(r.height::int::text, '')
      WHEN 'image' THEN COALESCE(r.width::int::text, '') || '×' || COALESCE(r.height::int::text, '')
      WHEN 'circle' THEN 'r=' || COALESCE(r.r::int::text, '')
      WHEN 'ellipse' THEN COALESCE(r.rx_::int::text, '') || '×' || COALESCE(r.ry_::int::text, '')
      ELSE '—'
    END;

    v_rows := v_rows || ARRAY[
      r.sort_order::text,
      v_indent || r.type,
      COALESCE(r.name, '—'),
      v_pos,
      v_dims,
      COALESCE(r.fill, '—')
    ];
  END LOOP;

  IF cardinality(v_rows) > 0 THEN
    v_body := v_body || '<h3>Éléments</h3>'
      || pgv.md_table(ARRAY['#', 'Type', 'Nom', 'Position', 'Dimensions', 'Fill'], v_rows, 20);
  END IF;

  -- Actions
  v_body := v_body || '<p>'
    || pgv.action('post_canvas_duplicate', 'Dupliquer', jsonb_build_object('p_source_id', p_id), 'Dupliquer ce canvas ?', 'outline')
    || ' '
    || pgv.action('post_canvas_delete', 'Supprimer', jsonb_build_object('p_id', p_id), 'Supprimer ce canvas et tous ses éléments ?', 'danger')
    || '</p>';

  RETURN v_body;
END;
$function$;
