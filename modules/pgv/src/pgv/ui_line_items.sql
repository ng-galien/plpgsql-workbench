CREATE OR REPLACE FUNCTION pgv.ui_line_items(p_source text, p_columns jsonb, p_totals jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'line_items', 'source', p_source, 'columns', p_columns)
    || CASE WHEN p_totals IS NOT NULL THEN jsonb_build_object('totals', p_totals) ELSE '{}'::jsonb END;
$function$;
