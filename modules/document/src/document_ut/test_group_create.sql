CREATE OR REPLACE FUNCTION document_ut.test_group_create()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_canvas_id uuid;
  v_e1 uuid; v_e2 uuid; v_e3 uuid;
  v_group_id uuid;
  v_row document.element;
  v_cnt int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  v_canvas_id := document.canvas_create('Group test');

  -- Create 3 sibling elements
  v_e1 := document.element_add(v_canvas_id, 'rect', 0, '{"x":0,"y":0,"width":50,"height":50}'::jsonb);
  v_e2 := document.element_add(v_canvas_id, 'rect', 1, '{"x":60,"y":0,"width":50,"height":50}'::jsonb);
  v_e3 := document.element_add(v_canvas_id, 'text', 2, '{"x":10,"y":100}'::jsonb);

  -- Group first two
  v_group_id := document.group_create(v_canvas_id, ARRAY[v_e1, v_e2], 'my-group');

  -- Verify group exists
  SELECT * INTO v_row FROM document.element WHERE id = v_group_id;
  RETURN NEXT ok(v_row.id IS NOT NULL, 'group element created');
  RETURN NEXT is(v_row.type, 'group', 'type is group');
  RETURN NEXT is(v_row.name, 'my-group', 'group name');
  RETURN NEXT ok(v_row.parent_id IS NULL, 'group parent is null (root level)');

  -- Verify children reparented
  SELECT count(*)::int INTO v_cnt FROM document.element WHERE parent_id = v_group_id;
  RETURN NEXT is(v_cnt, 2, '2 children in group');

  -- Third element still at root
  SELECT * INTO v_row FROM document.element WHERE id = v_e3;
  RETURN NEXT ok(v_row.parent_id IS NULL, 'third element still root');

  -- Cleanup
  DELETE FROM document.canvas WHERE id = v_canvas_id;
END;
$function$;
