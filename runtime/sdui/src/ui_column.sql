CREATE OR REPLACE FUNCTION sdui.ui_column(VARIADIC p_children jsonb[])
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'column', 'children', array_to_json(p_children)::jsonb);
$function$;
