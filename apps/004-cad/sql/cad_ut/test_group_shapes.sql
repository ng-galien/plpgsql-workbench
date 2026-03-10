CREATE OR REPLACE FUNCTION cad_ut.test_group_shapes()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_drawing_id int;
  v_layer_id int;
  v_s1 int; v_s2 int; v_s3 int;
  v_group_id int;
  v_svg text;
  v_count int;
BEGIN
  -- Setup
  INSERT INTO cad.drawing (name) VALUES ('test_group') RETURNING id INTO v_drawing_id;
  INSERT INTO cad.layer (drawing_id, name) VALUES (v_drawing_id, 'default') RETURNING id INTO v_layer_id;
  
  v_s1 := cad.add_shape(v_drawing_id, v_layer_id, 'line', '{"x1":0,"y1":0,"x2":100,"y2":0}');
  v_s2 := cad.add_shape(v_drawing_id, v_layer_id, 'line', '{"x1":100,"y1":0,"x2":100,"y2":100}');
  v_s3 := cad.add_shape(v_drawing_id, v_layer_id, 'rect', '{"x":200,"y":200,"w":50,"h":50}');

  -- Test group_shapes
  v_group_id := cad.group_shapes(v_drawing_id, ARRAY[v_s1, v_s2], 'Mur nord');
  RETURN NEXT ok(v_group_id IS NOT NULL, 'group created');
  RETURN NEXT ok(
    (SELECT type FROM cad.shape WHERE id = v_group_id) = 'group',
    'group type is group'
  );
  RETURN NEXT ok(
    (SELECT count(*) FROM cad.shape WHERE parent_id = v_group_id) = 2,
    'group has 2 children'
  );
  RETURN NEXT ok(
    (SELECT parent_id FROM cad.shape WHERE id = v_s3) IS NULL,
    's3 not in group'
  );

  -- Test SVG rendering with group
  v_svg := cad.render_svg(v_drawing_id);
  RETURN NEXT ok(v_svg LIKE '%data-group-id="' || v_group_id || '"%', 'svg contains group element');
  RETURN NEXT ok(v_svg LIKE '%data-label="Mur nord"%', 'group label rendered');

  -- Test move_group
  v_count := cad.move_group(v_group_id, 10, 20);
  RETURN NEXT is(v_count, 2, 'move_group moved 2 shapes');
  RETURN NEXT is(
    (SELECT (geometry->>'x1')::real FROM cad.shape WHERE id = v_s1),
    10::real, 'shape x1 moved +10'
  );

  -- Test ungroup
  v_count := cad.ungroup(v_group_id);
  RETURN NEXT is(v_count, 2, 'ungroup detached 2 shapes');
  RETURN NEXT ok(
    NOT EXISTS (SELECT 1 FROM cad.shape WHERE id = v_group_id),
    'group shape deleted'
  );
  RETURN NEXT ok(
    (SELECT parent_id FROM cad.shape WHERE id = v_s1) IS NULL,
    's1 detached after ungroup'
  );

  -- Cleanup
  DELETE FROM cad.drawing WHERE id = v_drawing_id;
END;
$function$;
