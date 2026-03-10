CREATE OR REPLACE FUNCTION cad.delete_shape(p_shape_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_drawing_id int;
BEGIN
  DELETE FROM cad.shape WHERE id = p_shape_id RETURNING drawing_id INTO v_drawing_id;
  IF v_drawing_id IS NOT NULL THEN
    UPDATE cad.drawing SET updated_at = now() WHERE id = v_drawing_id;
  END IF;
END;
$function$;
