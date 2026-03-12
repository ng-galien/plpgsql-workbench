CREATE OR REPLACE FUNCTION cad_ut.test_shape_delete()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_lid int;
  v_sid int;
  v_result text;
  v_count int;
BEGIN
  -- Setup
  INSERT INTO cad.drawing (name) VALUES ('test_shape_delete') RETURNING id INTO v_did;
  INSERT INTO cad.layer (drawing_id, name, color, stroke_width)
  VALUES (v_did, 'L1', '#000', 1) RETURNING id INTO v_lid;
  v_sid := cad.add_shape(v_did, v_lid, 'rect', '{"x":0,"y":0,"w":50,"h":30}'::jsonb);

  -- Test: null shape_id returns error
  v_result := cad.shape_delete(NULL, v_did);
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'null shape_id returns error');

  -- Test: valid delete returns success
  v_result := cad.shape_delete(v_sid, v_did);
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'delete returns success toast');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'delete returns redirect');

  -- Test: shape gone from DB
  SELECT count(*) INTO v_count FROM cad.shape WHERE id = v_sid;
  RETURN NEXT is(v_count, 0, 'shape deleted from DB');

  -- Cleanup
  DELETE FROM cad.layer WHERE drawing_id = v_did;
  DELETE FROM cad.drawing WHERE id = v_did;
END;
$function$;
