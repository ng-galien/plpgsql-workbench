CREATE OR REPLACE FUNCTION document_ut.test_element_add()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_canvas_id uuid;
  v_elem_id uuid;
  v_row document.element;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  v_canvas_id := document.canvas_create('Test elements');

  -- Add text
  v_elem_id := document.element_add(v_canvas_id, 'text', 0, '{"x":10,"y":20,"fill":"#000","name":"title"}'::jsonb);
  SELECT * INTO v_row FROM document.element WHERE id = v_elem_id;
  RETURN NEXT ok(v_row.id IS NOT NULL, 'text element created');
  RETURN NEXT ok(v_row.x = 10, 'text x=10');
  RETURN NEXT ok(v_row.y = 20, 'text y=20');
  RETURN NEXT is(v_row.fill, '#000', 'text fill');
  RETURN NEXT is(v_row.name, 'title', 'text name');

  -- Add rect
  v_elem_id := document.element_add(v_canvas_id, 'rect', 1, '{"x":0,"y":0,"width":100,"height":50,"fill":"#ff0000"}'::jsonb);
  SELECT * INTO v_row FROM document.element WHERE id = v_elem_id;
  RETURN NEXT ok(v_row.width = 100, 'rect width=100');
  RETURN NEXT ok(v_row.height = 50, 'rect height=50');

  -- Add line
  v_elem_id := document.element_add(v_canvas_id, 'line', 2, '{"x1":0,"y1":0,"x2":100,"y2":100}'::jsonb);
  SELECT * INTO v_row FROM document.element WHERE id = v_elem_id;
  RETURN NEXT ok(v_row.x1 = 0 AND v_row.x2 = 100, 'line geometry');

  -- Add circle
  v_elem_id := document.element_add(v_canvas_id, 'circle', 3, '{"cx":50,"cy":50,"r":25}'::jsonb);
  SELECT * INTO v_row FROM document.element WHERE id = v_elem_id;
  RETURN NEXT ok(v_row.r = 25, 'circle r=25');

  -- Cleanup
  DELETE FROM document.canvas WHERE id = v_canvas_id;
END;
$function$;
