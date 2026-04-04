CREATE OR REPLACE FUNCTION pgv.ui_row(VARIADIC p_children jsonb[])
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'row', 'children', array_to_json(p_children)::jsonb);
$function$;
