CREATE OR REPLACE FUNCTION cad.remove_piece(p_piece_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_label text;
  v_drawing_id int;
BEGIN
  SELECT label, drawing_id INTO v_label, v_drawing_id
  FROM cad.piece WHERE id = p_piece_id;

  IF NOT FOUND THEN
    RETURN 'error: piece #' || p_piece_id || ' not found';
  END IF;

  DELETE FROM cad.piece WHERE id = p_piece_id;

  RETURN 'removed: ' || coalesce(v_label, '#' || p_piece_id)
    || E'\n' || cad.inspect(v_drawing_id);
END;
$function$;
