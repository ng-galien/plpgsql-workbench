CREATE OR REPLACE FUNCTION sdui.ui_heading(p_text text, p_level integer DEFAULT 2)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'heading', 'text', p_text, 'level', p_level);
$function$;
