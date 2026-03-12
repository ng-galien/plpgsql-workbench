CREATE OR REPLACE FUNCTION cad_ut.test_shape_add()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_did int;
  v_lid int;
  v_result text;
  v_count int;
BEGIN
  -- Setup: create drawing + layer
  INSERT INTO cad.drawing (name) VALUES ('test_shape_add') RETURNING id INTO v_did;
  INSERT INTO cad.layer (drawing_id, name, color, stroke_width)
  VALUES (v_did, 'L1', '#000', 1) RETURNING id INTO v_lid;

  -- Test: missing params returns error
  v_result := cad.post_shape_add(v_did, NULL, NULL);
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'missing params returns error');

  -- Test: invalid geometry JSON returns error
  v_result := cad.post_shape_add(v_did, v_lid, 'line', '{bad json}');
  RETURN NEXT ok(v_result LIKE '%Géométrie JSON invalide%', 'bad geometry returns error');

  -- Test: invalid props JSON returns error
  v_result := cad.post_shape_add(v_did, v_lid, 'line', '{"x1":0}', '{bad}');
  RETURN NEXT ok(v_result LIKE '%Props JSON invalides%', 'bad props returns error');

  -- Test: valid shape_add returns success + redirect
  v_result := cad.post_shape_add(v_did, v_lid, 'line', '{"x1":0,"y1":0,"x2":100,"y2":0}', '{}', 'TestLine');
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'valid add returns success toast');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'valid add returns redirect');

  -- Test: shape exists in DB
  SELECT count(*) INTO v_count FROM cad.shape WHERE drawing_id = v_did AND label = 'TestLine';
  RETURN NEXT is(v_count, 1, 'shape created in DB');

  -- Cleanup
  DELETE FROM cad.shape WHERE drawing_id = v_did;
  DELETE FROM cad.layer WHERE drawing_id = v_did;
  DELETE FROM cad.drawing WHERE id = v_did;
END;
$function$;
