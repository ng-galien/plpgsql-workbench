CREATE OR REPLACE FUNCTION cad.move_shape(p_shape_id integer, p_dx real, p_dy real)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_shape cad.shape;
  v_g jsonb;
  v_pts jsonb;
BEGIN
  SELECT * INTO v_shape FROM cad.shape WHERE id = p_shape_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'shape % not found', p_shape_id; END IF;

  v_g := v_shape.geometry;

  CASE v_shape.type
    WHEN 'line', 'dimension' THEN
      v_g := jsonb_set(v_g, '{x1}', to_jsonb((v_g->>'x1')::real + p_dx));
      v_g := jsonb_set(v_g, '{y1}', to_jsonb((v_g->>'y1')::real + p_dy));
      v_g := jsonb_set(v_g, '{x2}', to_jsonb((v_g->>'x2')::real + p_dx));
      v_g := jsonb_set(v_g, '{y2}', to_jsonb((v_g->>'y2')::real + p_dy));

    WHEN 'rect' THEN
      v_g := jsonb_set(v_g, '{x}', to_jsonb((v_g->>'x')::real + p_dx));
      v_g := jsonb_set(v_g, '{y}', to_jsonb((v_g->>'y')::real + p_dy));

    WHEN 'circle', 'arc' THEN
      v_g := jsonb_set(v_g, '{cx}', to_jsonb((v_g->>'cx')::real + p_dx));
      v_g := jsonb_set(v_g, '{cy}', to_jsonb((v_g->>'cy')::real + p_dy));

    WHEN 'text' THEN
      v_g := jsonb_set(v_g, '{x}', to_jsonb((v_g->>'x')::real + p_dx));
      v_g := jsonb_set(v_g, '{y}', to_jsonb((v_g->>'y')::real + p_dy));

    WHEN 'polyline' THEN
      SELECT jsonb_agg(jsonb_build_array(
        (p->0)::real + p_dx,
        (p->1)::real + p_dy
      )) INTO v_pts
      FROM jsonb_array_elements(v_g->'points') AS p;
      v_g := jsonb_set(v_g, '{points}', v_pts);

    ELSE NULL;
  END CASE;

  UPDATE cad.shape SET geometry = v_g WHERE id = p_shape_id;
  UPDATE cad.drawing SET updated_at = now() WHERE id = v_shape.drawing_id;
END;
$function$;
