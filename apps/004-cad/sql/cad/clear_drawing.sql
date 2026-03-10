CREATE OR REPLACE FUNCTION cad.clear_drawing(p_drawing_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_count int;
BEGIN
  DELETE FROM cad.piece WHERE drawing_id = p_drawing_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN 'cleared: ' || v_count || ' pieces removed from drawing #' || p_drawing_id;
END;
$function$;
