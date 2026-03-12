CREATE OR REPLACE FUNCTION cad_ut.test_move_piece()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_pid int;
  v_result text;
  v_xmin_before float;
  v_xmin_after float;
BEGIN
  INSERT INTO cad.drawing (name) VALUES ('test_move') RETURNING id INTO v_did;
  v_pid := cad.add_beam(v_did, '60x90', ARRAY[0,0,0]::real[], ARRAY[1000,0,0]::real[], 'P1', 'montant');

  SELECT ST_XMin(geom) INTO v_xmin_before FROM cad.piece WHERE id = v_pid;

  v_result := cad.move_piece(v_pid, 500, 200, 100);
  RETURN NEXT ok(v_result LIKE '%moved P1%', 'move returns confirmation');

  SELECT ST_XMin(geom) INTO v_xmin_after FROM cad.piece WHERE id = v_pid;
  RETURN NEXT ok(abs(v_xmin_after - v_xmin_before - 500) < 0.1, 'X moved by 500');

  -- Not found
  v_result := cad.move_piece(-1, 0, 0, 0);
  RETURN NEXT is(v_result, 'piece not found', 'missing piece returns error');
END;
$function$;
