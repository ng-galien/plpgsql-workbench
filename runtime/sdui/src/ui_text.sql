CREATE OR REPLACE FUNCTION sdui.ui_text(p_value text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'text', 'value', p_value);
$function$;
