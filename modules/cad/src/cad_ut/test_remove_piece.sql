CREATE OR REPLACE FUNCTION cad_ut.test_remove_piece()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_pid int;
  v_result text;
  v_count int;
BEGIN
  INSERT INTO cad.drawing (name) VALUES ('test_remove') RETURNING id INTO v_did;
  v_pid := cad.add_beam(v_did, '60x90', ARRAY[0,0,0]::real[], ARRAY[1000,0,0]::real[], 'P1', 'montant');

  SELECT count(*) INTO v_count FROM cad.piece WHERE drawing_id = v_did;
  RETURN NEXT is(v_count, 1, 'piece exists before remove');

  v_result := cad.remove_piece(v_pid);
  RETURN NEXT ok(v_result LIKE '%removed: P1%', 'remove returns confirmation');

  SELECT count(*) INTO v_count FROM cad.piece WHERE drawing_id = v_did;
  RETURN NEXT is(v_count, 0, 'piece deleted after remove');

  -- Not found
  v_result := cad.remove_piece(-1);
  RETURN NEXT ok(v_result LIKE '%not found%', 'missing piece returns error');
END;
$function$;
