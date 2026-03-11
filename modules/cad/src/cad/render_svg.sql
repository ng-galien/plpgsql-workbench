CREATE OR REPLACE FUNCTION cad.render_svg(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_drawing cad.drawing;
  v_svg text := '';
  v_layer cad.layer;
  v_shape cad.shape;
  v_min_x real; v_min_y real; v_max_x real; v_max_y real;
  v_pad real := 50;
BEGIN
  SELECT * INTO v_drawing FROM cad.drawing WHERE id = p_drawing_id;
  IF NOT FOUND THEN RETURN ''; END IF;

  -- Marker pour les flèches de cotes
  v_svg := '<defs><marker id="arrow" viewBox="0 0 10 10" refX="5" refY="5"'
    || ' markerWidth="6" markerHeight="6" orient="auto-start-reverse">'
    || '<path d="M 0 0 L 10 5 L 0 10 z" fill="currentColor"/>'
    || '</marker></defs>';

  FOR v_layer IN
    SELECT * FROM cad.layer
    WHERE drawing_id = p_drawing_id AND visible
    ORDER BY sort_order
  LOOP
    v_svg := v_svg || format(
      '<g id="layer-%s" stroke="%s" stroke-width="%s" fill="none">',
      v_layer.id, v_layer.color, v_layer.stroke_width
    );

    -- All shapes in this layer
    FOR v_shape IN
      SELECT * FROM cad.shape
      WHERE layer_id = v_layer.id
      ORDER BY sort_order
    LOOP
      IF v_shape.type = 'group' THEN
        v_svg := v_svg || cad.render_group_svg(v_shape.id, v_layer.color, v_drawing.unit);
      ELSE
        v_svg := v_svg || cad.render_shape_svg(v_shape, v_layer.color, v_drawing.unit);
      END IF;
    END LOOP;

    v_svg := v_svg || '</g>';
  END LOOP;

  -- Bounding box dynamique (ignore les shapes de type group)
  SELECT
    min(LEAST(
      COALESCE((s.geometry->>'x')::real, (s.geometry->>'x1')::real, (s.geometry->>'cx')::real, 0),
      COALESCE((s.geometry->>'x2')::real, (s.geometry->>'x')::real, (s.geometry->>'cx')::real, 0)
    )),
    min(LEAST(
      COALESCE((s.geometry->>'y')::real, (s.geometry->>'y1')::real, (s.geometry->>'cy')::real, 0),
      COALESCE((s.geometry->>'y2')::real, (s.geometry->>'y')::real, (s.geometry->>'cy')::real, 0)
    )),
    max(GREATEST(
      COALESCE((s.geometry->>'x')::real + COALESCE((s.geometry->>'w')::real, 0), 0),
      COALESCE((s.geometry->>'x2')::real, 0),
      COALESCE((s.geometry->>'cx')::real + COALESCE((s.geometry->>'r')::real, 0), 0)
    )),
    max(GREATEST(
      COALESCE((s.geometry->>'y')::real + COALESCE((s.geometry->>'h')::real, 0), 0),
      COALESCE((s.geometry->>'y2')::real, 0),
      COALESCE((s.geometry->>'cy')::real + COALESCE((s.geometry->>'r')::real, 0), 0)
    ))
  INTO v_min_x, v_min_y, v_max_x, v_max_y
  FROM cad.shape s
  WHERE s.drawing_id = p_drawing_id AND s.type <> 'group';

  v_min_x := COALESCE(v_min_x, 0) - v_pad;
  v_min_y := COALESCE(v_min_y, 0) - v_pad;
  v_max_x := COALESCE(v_max_x, v_drawing.width) + v_pad;
  v_max_y := COALESCE(v_max_y, v_drawing.height) + v_pad;

  RETURN format(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s %s %s %s" class="cad-canvas">%s</svg>',
    v_min_x, v_min_y, v_max_x - v_min_x, v_max_y - v_min_y, v_svg
  );
END;
$function$;
