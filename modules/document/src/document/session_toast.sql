CREATE OR REPLACE FUNCTION document.session_toast(p_canvas_id uuid, p_text text, p_level text DEFAULT 'info'::text, p_duration integer DEFAULT 3000, p_user_id text DEFAULT document.current_user_id())
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO document.session (canvas_id, user_id, toast, updated_at)
  VALUES (p_canvas_id, p_user_id, jsonb_build_object('text', p_text, 'level', p_level, 'duration', p_duration, 'at', now()), now())
  ON CONFLICT (canvas_id, user_id) DO UPDATE SET
    toast = jsonb_build_object('text', p_text, 'level', p_level, 'duration', p_duration, 'at', now()),
    updated_at = now();
END;
$function$;
