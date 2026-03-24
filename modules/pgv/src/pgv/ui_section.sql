CREATE OR REPLACE FUNCTION pgv.ui_section(p_label text, VARIADIC p_children jsonb[])
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'section', 'label', p_label, 'children', array_to_json(p_children)::jsonb);
$function$;
