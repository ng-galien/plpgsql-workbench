CREATE OR REPLACE FUNCTION cad_ut.test_drawing_add()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_id int;
  v_layer_count int;
BEGIN
  -- Test: empty name returns error toast
  v_result := cad.post_drawing_add('');
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'empty name returns error toast');

  -- Test: null name returns error toast
  v_result := cad.post_drawing_add(NULL);
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'null name returns error toast');

  -- Test: valid name creates drawing + redirects
  v_result := cad.post_drawing_add('Test Audit');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'valid name returns redirect');

  -- Get created drawing
  SELECT id INTO v_id FROM cad.drawing WHERE name = 'Test Audit' ORDER BY id DESC LIMIT 1;
  RETURN NEXT ok(v_id IS NOT NULL, 'drawing created in DB');

  -- Test: default layer created
  SELECT count(*) INTO v_layer_count FROM cad.layer WHERE drawing_id = v_id;
  RETURN NEXT is(v_layer_count, 1, 'default layer created');

  -- Cleanup
  DELETE FROM cad.layer WHERE drawing_id = v_id;
  DELETE FROM cad.drawing WHERE id = v_id;
END;
$function$;
