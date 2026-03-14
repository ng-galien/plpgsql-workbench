CREATE OR REPLACE FUNCTION document_ut.test_session_sync()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_canvas_id uuid;
  v_state jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  v_canvas_id := document.canvas_create('Session test');

  -- Default state (no session row)
  v_state := document.session_get(v_canvas_id);
  RETURN NEXT is(v_state->>'phase', 'idle', 'default phase is idle');
  RETURN NEXT ok((v_state->>'zoom')::real = 1, 'default zoom is 1');

  -- Sync
  PERFORM document.session_sync(v_canvas_id, '["id1","id2"]'::jsonb, 'selected', 1.5);
  v_state := document.session_get(v_canvas_id);
  RETURN NEXT is(v_state->>'phase', 'selected', 'phase updated to selected');
  RETURN NEXT ok((v_state->>'zoom')::real = 1.5, 'zoom updated to 1.5');
  RETURN NEXT ok(jsonb_array_length(v_state->'selected_ids') = 2, '2 selected ids');

  -- Update sync
  PERFORM document.session_sync(v_canvas_id, '[]'::jsonb, 'idle', 2.0);
  v_state := document.session_get(v_canvas_id);
  RETURN NEXT is(v_state->>'phase', 'idle', 'phase back to idle');
  RETURN NEXT ok(jsonb_array_length(v_state->'selected_ids') = 0, '0 selected ids');

  -- Cleanup
  DELETE FROM document.session WHERE canvas_id = v_canvas_id;
  DELETE FROM document.canvas WHERE id = v_canvas_id;
END;
$function$;
