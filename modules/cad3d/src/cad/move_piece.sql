CREATE OR REPLACE FUNCTION cad.move_piece(p_piece_id integer, p_dx real DEFAULT 0, p_dy real DEFAULT 0, p_dz real DEFAULT 0)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_piece cad.piece;
BEGIN
  SELECT * INTO v_piece FROM cad.piece WHERE id = p_piece_id;
  IF NOT FOUND THEN RETURN 'piece not found'; END IF;

  UPDATE cad.piece SET
    geom = ST_Translate(geom, p_dx, p_dy, p_dz),
    profile = ST_Translate(profile, p_dx, p_dy, p_dz)
  WHERE id = p_piece_id;

  RETURN format('moved %s by [%s, %s, %s] -> now [%s,%s,%s]->[%s,%s,%s]',
    v_piece.label, p_dx, p_dy, p_dz,
    round((ST_XMin(v_piece.geom) + p_dx)::numeric),
    round((ST_YMin(v_piece.geom) + p_dy)::numeric),
    round((ST_ZMin(v_piece.geom) + p_dz)::numeric),
    round((ST_XMax(v_piece.geom) + p_dx)::numeric),
    round((ST_YMax(v_piece.geom) + p_dy)::numeric),
    round((ST_ZMax(v_piece.geom) + p_dz)::numeric)
  );
END;
$function$;
