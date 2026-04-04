CREATE OR REPLACE FUNCTION pgv.ui_stat(p_value text, p_label text, p_variant text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'stat', 'value', p_value, 'label', p_label)
    || CASE WHEN p_variant IS NOT NULL THEN jsonb_build_object('variant', p_variant) ELSE '{}'::jsonb END;
$function$;
