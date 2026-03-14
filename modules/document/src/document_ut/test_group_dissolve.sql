CREATE OR REPLACE FUNCTION document_ut.test_group_dissolve()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_canvas_id uuid;
  v_e1 uuid; v_e2 uuid;
  v_group_id uuid;
  v_freed int;
  v_row document.element;
  v_grp_exists boolean;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  v_canvas_id := document.canvas_create('Dissolve test');

  v_e1 := document.element_add(v_canvas_id, 'rect', 0, '{"x":0,"y":0,"width":50,"height":50}'::jsonb);
  v_e2 := document.element_add(v_canvas_id, 'text', 1, '{"x":10,"y":10}'::jsonb);

  v_group_id := document.group_create(v_canvas_id, ARRAY[v_e1, v_e2], 'temp-group');

  -- Dissolve
  v_freed := document.group_dissolve(v_group_id);
  RETURN NEXT is(v_freed, 2, '2 children freed');

  -- Group element should be gone
  SELECT EXISTS(SELECT 1 FROM document.element WHERE id = v_group_id) INTO v_grp_exists;
  RETURN NEXT ok(NOT v_grp_exists, 'group element deleted');

  -- Children back to root
  SELECT * INTO v_row FROM document.element WHERE id = v_e1;
  RETURN NEXT ok(v_row.parent_id IS NULL, 'child 1 back to root');
  SELECT * INTO v_row FROM document.element WHERE id = v_e2;
  RETURN NEXT ok(v_row.parent_id IS NULL, 'child 2 back to root');

  -- Cleanup
  DELETE FROM document.canvas WHERE id = v_canvas_id;
END;
$function$;
