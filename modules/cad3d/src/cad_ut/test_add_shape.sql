CREATE OR REPLACE FUNCTION cad_ut.test_add_shape()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_lid int;
  v_sid int;
BEGIN
  INSERT INTO cad.drawing (name) VALUES ('test_add') RETURNING id INTO v_did;
  INSERT INTO cad.layer (drawing_id, name) VALUES (v_did, 'L1') RETURNING id INTO v_lid;

  v_sid := cad.add_shape(v_did, v_lid, 'line', '{"x1":0,"y1":0,"x2":100,"y2":0}');
  RETURN NEXT ok(v_sid IS NOT NULL, 'add_shape returns an id');
  RETURN NEXT is(
    (SELECT type FROM cad.shape WHERE id = v_sid), 'line', 'shape type is line'
  );
  RETURN NEXT is(
    (SELECT geometry->>'x2' FROM cad.shape WHERE id = v_sid), '100', 'geometry x2 = 100'
  );
END;
$function$;
