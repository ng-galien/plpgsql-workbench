CREATE OR REPLACE FUNCTION document.canvas_duplicate(p_source_id uuid, p_new_name text)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_new_id uuid;
  v_src document.canvas;
  v_map jsonb := '{}'; -- old_id -> new_id mapping
  r record;
  v_new_elem_id uuid;
  v_new_parent uuid;
BEGIN
  -- Copy canvas
  SELECT * INTO v_src FROM document.canvas
  WHERE id = p_source_id AND tenant_id = current_setting('app.tenant_id', true);

  IF v_src IS NULL THEN
    RAISE EXCEPTION 'Canvas not found: %', p_source_id;
  END IF;

  INSERT INTO document.canvas (name, format, orientation, width, height, background, category, meta, template_id)
  VALUES (p_new_name, v_src.format, v_src.orientation, v_src.width, v_src.height, v_src.background, v_src.category, v_src.meta, v_src.template_id)
  RETURNING id INTO v_new_id;

  -- Copy gradients
  INSERT INTO document.gradient (canvas_id, type, angle, cx, cy, gr, stops)
  SELECT v_new_id, g.type, g.angle, g.cx, g.cy, g.gr, g.stops
  FROM document.gradient g WHERE g.canvas_id = p_source_id;

  -- Copy elements (parents first via sort on parent_id nulls first)
  FOR r IN
    SELECT * FROM document.element
    WHERE canvas_id = p_source_id
    ORDER BY parent_id NULLS FIRST, sort_order
  LOOP
    v_new_parent := NULL;
    IF r.parent_id IS NOT NULL THEN
      v_new_parent := (v_map->>r.parent_id::text)::uuid;
    END IF;

    INSERT INTO document.element (
      canvas_id, type, parent_id, sort_order, name,
      x, y, width, height, x1, y1, x2, y2, cx, cy, r, rx_, ry_,
      opacity, rotation, fill, stroke, stroke_width, stroke_dasharray,
      props, asset_id
    ) VALUES (
      v_new_id, r.type, v_new_parent, r.sort_order, r.name,
      r.x, r.y, r.width, r.height, r.x1, r.y1, r.x2, r.y2, r.cx, r.cy, r.r, r.rx_, r.ry_,
      r.opacity, r.rotation, r.fill, r.stroke, r.stroke_width, r.stroke_dasharray,
      r.props, r.asset_id
    ) RETURNING id INTO v_new_elem_id;

    v_map := v_map || jsonb_build_object(r.id::text, v_new_elem_id);
  END LOOP;

  RETURN v_new_id;
END;
$function$;
