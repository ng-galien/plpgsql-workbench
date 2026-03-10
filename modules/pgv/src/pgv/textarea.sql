CREATE OR REPLACE FUNCTION pgv.textarea(p_name text, p_label text, p_value text DEFAULT NULL::text, p_rows integer DEFAULT 3)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT '<label>' || p_label
    || '<textarea name="' || p_name || '" rows="' || p_rows || '">'
    || coalesce(pgv.esc(p_value), '')
    || '</textarea></label>';
$function$;
