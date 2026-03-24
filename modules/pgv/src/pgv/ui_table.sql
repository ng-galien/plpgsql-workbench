CREATE OR REPLACE FUNCTION pgv.ui_table(p_source text, p_columns jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'table', 'source', p_source, 'columns', p_columns);
$function$;
