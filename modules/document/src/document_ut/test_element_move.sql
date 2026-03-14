CREATE OR REPLACE FUNCTION document_ut.test_element_move()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_canvas_id uuid;
  v_e1 uuid; v_e2 uuid; v_e3 uuid;
  v_group_id uuid;
  v_moved int;
  v_row document.element;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  v_canvas_id := document.canvas_create('Move test');

  -- Create elements: rect, circle, line
  v_e1 := document.element_add(v_canvas_id, 'rect', 0, '{"x":10,"y":20,"width":100,"height":50}'::jsonb);
  v_e2 := document.element_add(v_canvas_id, 'circle', 1, '{"cx":50,"cy":60,"r":25}'::jsonb);
  v_e3 := document.element_add(v_canvas_id, 'line', 2, '{"x1":0,"y1":0,"x2":100,"y2":100}'::jsonb);

  -- Group them
  v_group_id := document.group_create(v_canvas_id, ARRAY[v_e1, v_e2, v_e3], 'movable');

  -- Move group by +10, +5
  v_moved := document.element_move(v_group_id, 10, 5);
  RETURN NEXT is(v_moved, 3, '3 elements moved');

  -- Verify rect moved
  SELECT * INTO v_row FROM document.element WHERE id = v_e1;
  RETURN NEXT ok(v_row.x = 20, 'rect x: 10+10=20');
  RETURN NEXT ok(v_row.y = 25, 'rect y: 20+5=25');

  -- Verify circle moved
  SELECT * INTO v_row FROM document.element WHERE id = v_e2;
  RETURN NEXT ok(v_row.cx = 60, 'circle cx: 50+10=60');
  RETURN NEXT ok(v_row.cy = 65, 'circle cy: 60+5=65');

  -- Verify line moved
  SELECT * INTO v_row FROM document.element WHERE id = v_e3;
  RETURN NEXT ok(v_row.x1 = 10, 'line x1: 0+10=10');
  RETURN NEXT ok(v_row.y1 = 5, 'line y1: 0+5=5');
  RETURN NEXT ok(v_row.x2 = 110, 'line x2: 100+10=110');
  RETURN NEXT ok(v_row.y2 = 105, 'line y2: 100+5=105');

  -- Move single leaf
  v_moved := document.element_move(v_e1, -5, -5);
  RETURN NEXT is(v_moved, 1, '1 element moved (single)');
  SELECT * INTO v_row FROM document.element WHERE id = v_e1;
  RETURN NEXT ok(v_row.x = 15, 'rect x after second move: 20-5=15');

  -- Cleanup
  DELETE FROM document.canvas WHERE id = v_canvas_id;
END;
$function$;
