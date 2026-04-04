CREATE OR REPLACE FUNCTION sdui.ui_detail(p_source text, p_fields jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'detail', 'source', p_source, 'fields', p_fields);
$function$;
