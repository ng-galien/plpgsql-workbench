CREATE OR REPLACE FUNCTION document.canvas_get_state(p_canvas_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_canvas jsonb;
  v_elements jsonb;
  v_gradients jsonb;
BEGIN
  -- Canvas metadata
  SELECT jsonb_build_object(
    'id', c.id, 'name', c.name, 'format', c.format,
    'orientation', c.orientation, 'width', c.width, 'height', c.height,
    'background', c.background, 'category', c.category, 'meta', c.meta
  ) INTO v_canvas
  FROM document.canvas c
  WHERE c.id = p_canvas_id
    AND c.tenant_id = current_setting('app.tenant_id', true);

  IF v_canvas IS NULL THEN
    RETURN NULL;
  END IF;

  -- Elements as flat list (frontend builds the tree via parent_id)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', e.id, 'type', e.type, 'parent_id', e.parent_id,
      'sort_order', e.sort_order, 'name', e.name,
      'x', e.x, 'y', e.y, 'width', e.width, 'height', e.height,
      'x1', e.x1, 'y1', e.y1, 'x2', e.x2, 'y2', e.y2,
      'cx', e.cx, 'cy', e.cy, 'r', e.r, 'rx', e.rx_, 'ry', e.ry_,
      'opacity', e.opacity, 'rotation', e.rotation,
      'fill', e.fill, 'stroke', e.stroke,
      'stroke_width', e.stroke_width, 'stroke_dasharray', e.stroke_dasharray,
      'props', e.props, 'asset_id', e.asset_id
    ) ORDER BY e.sort_order
  ), '[]') INTO v_elements
  FROM document.element e
  WHERE e.canvas_id = p_canvas_id;

  -- Gradients
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', g.id, 'type', g.type, 'angle', g.angle,
      'cx', g.cx, 'cy', g.cy, 'r', g.gr, 'stops', g.stops
    )
  ), '[]') INTO v_gradients
  FROM document.gradient g
  WHERE g.canvas_id = p_canvas_id;

  RETURN v_canvas || jsonb_build_object('elements', v_elements, 'gradients', v_gradients);
END;
$function$;
