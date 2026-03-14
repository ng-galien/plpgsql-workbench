CREATE OR REPLACE FUNCTION document_ut.test_canvas_create()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id uuid;
  v_row document.canvas;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Default A4 portrait
  v_id := document.canvas_create('Test A4');
  SELECT * INTO v_row FROM document.canvas WHERE id = v_id;
  RETURN NEXT ok(v_row.id IS NOT NULL, 'canvas created');
  RETURN NEXT is(v_row.name, 'Test A4', 'name matches');
  RETURN NEXT is(v_row.format, 'A4', 'format A4');
  RETURN NEXT is(v_row.orientation, 'portrait', 'portrait');
  RETURN NEXT ok(v_row.width = 794, 'A4 width 794');
  RETURN NEXT ok(v_row.height = 1123, 'A4 height 1123');

  -- Landscape
  v_id := document.canvas_create('Test landscape', 'A4', 'paysage');
  SELECT * INTO v_row FROM document.canvas WHERE id = v_id;
  RETURN NEXT ok(v_row.width > v_row.height, 'landscape width > height');

  -- Custom dimensions
  v_id := document.canvas_create('Custom', 'CUSTOM', 'portrait', 500, 800);
  SELECT * INTO v_row FROM document.canvas WHERE id = v_id;
  RETURN NEXT ok(v_row.width = 500, 'custom width');
  RETURN NEXT ok(v_row.height = 800, 'custom height');

  -- Cleanup
  DELETE FROM document.canvas WHERE tenant_id = 'test';
END;
$function$;
