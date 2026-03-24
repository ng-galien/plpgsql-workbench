CREATE OR REPLACE FUNCTION pgv.ui_color(p_value text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'color', 'value', p_value);
$function$;
