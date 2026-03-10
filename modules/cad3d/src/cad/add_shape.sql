CREATE OR REPLACE FUNCTION cad.add_shape(p_drawing_id integer, p_layer_id integer, p_type text, p_geometry jsonb, p_props jsonb DEFAULT '{}'::jsonb, p_label text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_order int;
BEGIN
  SELECT COALESCE(max(sort_order), 0) + 1 INTO v_order
  FROM cad.shape WHERE drawing_id = p_drawing_id;

  INSERT INTO cad.shape (drawing_id, layer_id, type, geometry, props, label, sort_order)
  VALUES (p_drawing_id, p_layer_id, p_type, p_geometry, p_props, p_label, v_order)
  RETURNING id INTO v_id;

  UPDATE cad.drawing SET updated_at = now() WHERE id = p_drawing_id;

  RETURN v_id;
END;
$function$;
