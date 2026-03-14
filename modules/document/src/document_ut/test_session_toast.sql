CREATE OR REPLACE FUNCTION document_ut.test_session_toast()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_canvas_id uuid;
  v_state jsonb;
  v_toast jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  v_canvas_id := document.canvas_create('Toast test');

  -- Set toast
  PERFORM document.session_toast(v_canvas_id, 'Element added', 'success', 2000);
  v_state := document.session_get(v_canvas_id);
  v_toast := v_state->'toast';

  RETURN NEXT ok(v_toast IS NOT NULL, 'toast is set');
  RETURN NEXT is(v_toast->>'text', 'Element added', 'toast text matches');
  RETURN NEXT is(v_toast->>'level', 'success', 'toast level matches');
  RETURN NEXT ok((v_toast->>'duration')::int = 2000, 'toast duration matches');
  RETURN NEXT ok(v_toast ? 'at', 'toast has timestamp');

  -- Canvas get_state includes session
  v_state := document.canvas_get_state(v_canvas_id);
  RETURN NEXT ok(v_state ? 'session', 'canvas_get_state has session key');
  RETURN NEXT is(v_state->'session'->'toast'->>'text', 'Element added', 'session toast in canvas state');

  -- Cleanup
  DELETE FROM document.session WHERE canvas_id = v_canvas_id;
  DELETE FROM document.canvas WHERE id = v_canvas_id;
END;
$function$;
