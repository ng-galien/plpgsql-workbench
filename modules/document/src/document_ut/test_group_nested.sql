CREATE OR REPLACE FUNCTION document_ut.test_group_nested()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_canvas_id uuid;
  v_e1 uuid; v_e2 uuid; v_e3 uuid;
  v_g1 uuid; v_g2 uuid;
  v_state jsonb;
  v_nested_cnt int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  v_canvas_id := document.canvas_create('Nested test');

  -- Create elements
  v_e1 := document.element_add(v_canvas_id, 'rect', 0, '{"x":0,"y":0,"width":50,"height":50}'::jsonb);
  v_e2 := document.element_add(v_canvas_id, 'rect', 1, '{"x":60,"y":0,"width":50,"height":50}'::jsonb);
  v_e3 := document.element_add(v_canvas_id, 'text', 2, '{"x":10,"y":100}'::jsonb);

  -- Group e1+e2 into g1
  v_g1 := document.group_create(v_canvas_id, ARRAY[v_e1, v_e2], 'outer');

  -- Group g1+e3 into g2 (nested: g2 contains g1 which contains e1,e2)
  v_g2 := document.group_create(v_canvas_id, ARRAY[v_g1, v_e3], 'wrapper');

  -- Verify state
  v_state := document.canvas_get_state(v_canvas_id);
  RETURN NEXT ok(jsonb_array_length(v_state->'elements') = 5, '5 elements total (2 groups + 3 shapes)');

  -- g2 is root
  RETURN NEXT ok(
    (SELECT e->>'parent_id' IS NULL FROM jsonb_array_elements(v_state->'elements') e WHERE e->>'id' = v_g2::text),
    'wrapper group at root'
  );

  -- g1 is child of g2
  RETURN NEXT ok(
    (SELECT e->>'parent_id' = v_g2::text FROM jsonb_array_elements(v_state->'elements') e WHERE e->>'id' = v_g1::text),
    'outer group inside wrapper'
  );

  -- e1 is child of g1
  RETURN NEXT ok(
    (SELECT e->>'parent_id' = v_g1::text FROM jsonb_array_elements(v_state->'elements') e WHERE e->>'id' = v_e1::text),
    'rect inside outer group'
  );

  -- Count elements with parent_id set
  SELECT count(*)::int INTO v_nested_cnt
  FROM jsonb_array_elements(v_state->'elements') e
  WHERE e->>'parent_id' IS NOT NULL;
  RETURN NEXT is(v_nested_cnt, 4, '4 elements have parent_id (g1, e1, e2, e3)');

  -- Cleanup
  DELETE FROM document.canvas WHERE id = v_canvas_id;
END;
$function$;
