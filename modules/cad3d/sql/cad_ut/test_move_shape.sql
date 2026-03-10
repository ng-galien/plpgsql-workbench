CREATE OR REPLACE FUNCTION cad_ut.test_move_shape()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_lid int;
  v_sid int;
  v_g jsonb;
BEGIN
  INSERT INTO cad.drawing (name) VALUES ('test_move') RETURNING id INTO v_did;
  INSERT INTO cad.layer (drawing_id, name) VALUES (v_did, 'L1') RETURNING id INTO v_lid;

  v_sid := cad.add_shape(v_did, v_lid, 'line', '{"x1":0,"y1":0,"x2":100,"y2":0}');
  PERFORM cad.move_shape(v_sid, 10, 20);

  SELECT geometry INTO v_g FROM cad.shape WHERE id = v_sid;
  RETURN NEXT is((v_g->>'x1')::real, 10::real, 'x1 moved +10');
  RETURN NEXT is((v_g->>'y1')::real, 20::real, 'y1 moved +20');
  RETURN NEXT is((v_g->>'x2')::real, 110::real, 'x2 moved +10');
END;
$function$;
