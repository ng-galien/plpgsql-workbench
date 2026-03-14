CREATE OR REPLACE FUNCTION document.session_get(p_canvas_id uuid, p_user_id text DEFAULT document.current_user_id())
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row document.session;
BEGIN
  SELECT * INTO v_row FROM document.session WHERE canvas_id = p_canvas_id AND user_id = p_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('selected_ids', '[]'::jsonb, 'phase', 'idle', 'zoom', 1, 'toast', null);
  END IF;
  RETURN jsonb_build_object(
    'selected_ids', v_row.selected_ids,
    'phase', v_row.phase,
    'zoom', v_row.zoom,
    'toast', v_row.toast
  );
END;
$function$;
