CREATE OR REPLACE FUNCTION pgv.input(p_name text, p_type text, p_label text, p_value text DEFAULT NULL::text, p_required boolean DEFAULT false)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<label>' || p_label
    || CASE WHEN p_required THEN ' <sup>*</sup>' ELSE '' END
    || '<input name="' || p_name || '" type="' || p_type || '"'
    || CASE WHEN p_value IS NOT NULL THEN ' value="' || pgv.esc(p_value) || '"' ELSE '' END
    || CASE WHEN p_required THEN ' required' ELSE '' END
    || '></label>';
$function$;
