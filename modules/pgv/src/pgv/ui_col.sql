CREATE OR REPLACE FUNCTION pgv.ui_col(p_key text, p_label text, p_cell jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('key', p_key, 'label', p_label) 
    || CASE WHEN p_cell IS NOT NULL THEN jsonb_build_object('cell', p_cell) ELSE '{}'::jsonb END;
$function$;
