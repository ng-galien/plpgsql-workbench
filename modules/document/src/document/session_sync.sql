CREATE OR REPLACE FUNCTION document.session_sync(p_canvas_id uuid, p_selected_ids jsonb DEFAULT '[]'::jsonb, p_phase text DEFAULT 'idle'::text, p_zoom real DEFAULT 1, p_user_id text DEFAULT document.current_user_id())
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO document.session (canvas_id, user_id, selected_ids, phase, zoom, updated_at)
  VALUES (p_canvas_id, p_user_id, p_selected_ids, p_phase, p_zoom, now())
  ON CONFLICT (canvas_id, user_id) DO UPDATE SET
    selected_ids = EXCLUDED.selected_ids,
    phase = EXCLUDED.phase,
    zoom = EXCLUDED.zoom,
    updated_at = now();
END;
$function$;
