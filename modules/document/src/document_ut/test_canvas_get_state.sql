CREATE OR REPLACE FUNCTION document_ut.test_canvas_get_state()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_canvas_id uuid;
  v_group_id uuid;
  v_state jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  v_canvas_id := document.canvas_create('State test');

  -- Add group
  v_group_id := document.element_add(v_canvas_id, 'group', 0, '{"name":"header"}'::jsonb);

  -- Add child rect in group
  PERFORM document.element_add(v_canvas_id, 'rect', 1,
    jsonb_build_object('x',0,'y',0,'width',100,'height',50,'parent_id', v_group_id));

  -- Add standalone text
  PERFORM document.element_add(v_canvas_id, 'text', 2, '{"x":10,"y":200}'::jsonb);

  -- Get state
  v_state := document.canvas_get_state(v_canvas_id);
  RETURN NEXT ok(v_state IS NOT NULL, 'state returned');
  RETURN NEXT is(v_state->>'name', 'State test', 'canvas name in state');
  RETURN NEXT ok(v_state ? 'elements', 'has elements key');
  RETURN NEXT ok(v_state ? 'gradients', 'has gradients key');
  RETURN NEXT ok(jsonb_array_length(v_state->'elements') = 3, '3 elements (group + rect + text)');

  -- Verify group element has children via parent_id
  RETURN NEXT ok(
    (SELECT count(*) FROM jsonb_array_elements(v_state->'elements') e WHERE e->>'parent_id' IS NOT NULL) = 1,
    '1 element has parent_id'
  );

  -- Cleanup
  DELETE FROM document.canvas WHERE id = v_canvas_id;
END;
$function$;
