CREATE OR REPLACE FUNCTION pgv.ui_field(p_key text, p_type text, p_label text, p_required boolean DEFAULT false, p_options jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT jsonb_build_object('type', 'field', 'key', p_key, 'fieldType', p_type, 'label', p_label, 'required', p_required)
    || CASE WHEN p_options IS NOT NULL THEN jsonb_build_object('options', p_options) ELSE '{}'::jsonb END;
$function$;
