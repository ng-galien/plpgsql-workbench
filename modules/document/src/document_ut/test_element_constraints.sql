CREATE OR REPLACE FUNCTION document_ut.test_element_constraints()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_canvas_id uuid;
  v_ok boolean;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  v_canvas_id := document.canvas_create('Test constraints');

  -- rect without width should fail
  BEGIN
    PERFORM document.element_add(v_canvas_id, 'rect', 0, '{"x":0,"y":0,"height":50}'::jsonb);
    v_ok := false;
  EXCEPTION WHEN check_violation THEN
    v_ok := true;
  END;
  RETURN NEXT ok(v_ok, 'rect without width rejected');

  -- line without x2/y2 should fail
  BEGIN
    PERFORM document.element_add(v_canvas_id, 'line', 0, '{"x1":0,"y1":0}'::jsonb);
    v_ok := false;
  EXCEPTION WHEN check_violation THEN
    v_ok := true;
  END;
  RETURN NEXT ok(v_ok, 'line without x2/y2 rejected');

  -- circle without r should fail
  BEGIN
    PERFORM document.element_add(v_canvas_id, 'circle', 0, '{"cx":50,"cy":50}'::jsonb);
    v_ok := false;
  EXCEPTION WHEN check_violation THEN
    v_ok := true;
  END;
  RETURN NEXT ok(v_ok, 'circle without r rejected');

  -- ellipse without rx/ry should fail
  BEGIN
    PERFORM document.element_add(v_canvas_id, 'ellipse', 0, '{"cx":50,"cy":50}'::jsonb);
    v_ok := false;
  EXCEPTION WHEN check_violation THEN
    v_ok := true;
  END;
  RETURN NEXT ok(v_ok, 'ellipse without rx/ry rejected');

  -- text without x/y should fail
  BEGIN
    PERFORM document.element_add(v_canvas_id, 'text', 0, '{"fill":"#000"}'::jsonb);
    v_ok := false;
  EXCEPTION WHEN check_violation THEN
    v_ok := true;
  END;
  RETURN NEXT ok(v_ok, 'text without x/y rejected');

  -- negative width should fail
  BEGIN
    PERFORM document.element_add(v_canvas_id, 'rect', 0, '{"x":0,"y":0,"width":-10,"height":50}'::jsonb);
    v_ok := false;
  EXCEPTION WHEN check_violation THEN
    v_ok := true;
  END;
  RETURN NEXT ok(v_ok, 'negative width rejected');

  -- path without d in props should fail
  BEGIN
    PERFORM document.element_add(v_canvas_id, 'path', 0, '{"fill":"#000"}'::jsonb);
    v_ok := false;
  EXCEPTION WHEN check_violation THEN
    v_ok := true;
  END;
  RETURN NEXT ok(v_ok, 'path without d rejected');

  -- Cleanup
  DELETE FROM document.canvas WHERE id = v_canvas_id;
END;
$function$;
