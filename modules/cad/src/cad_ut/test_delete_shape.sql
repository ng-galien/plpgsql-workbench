CREATE OR REPLACE FUNCTION cad_ut.test_delete_shape()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_lid int;
  v_sid int;
BEGIN
  INSERT INTO cad.drawing (name) VALUES ('test_del') RETURNING id INTO v_did;
  INSERT INTO cad.layer (drawing_id, name) VALUES (v_did, 'L1') RETURNING id INTO v_lid;

  v_sid := cad.add_shape(v_did, v_lid, 'rect', '{"x":0,"y":0,"w":50,"h":30}');
  PERFORM cad.delete_shape(v_sid);

  RETURN NEXT ok(
    NOT EXISTS(SELECT 1 FROM cad.shape WHERE id = v_sid),
    'shape deleted'
  );
END;
$function$;
