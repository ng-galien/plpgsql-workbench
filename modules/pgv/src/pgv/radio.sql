CREATE OR REPLACE FUNCTION pgv.radio(p_name text, p_label text, p_options jsonb, p_selected text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_html text;
  v_opt text;
BEGIN
  v_html := '<fieldset><legend>' || pgv.esc(p_label) || '</legend>';
  FOR v_opt IN SELECT jsonb_array_elements_text(p_options)
  LOOP
    v_html := v_html || '<label><input type="radio" name="' || p_name || '" value="' || pgv.esc(v_opt) || '"'
      || CASE WHEN v_opt = p_selected THEN ' checked' ELSE '' END
      || '> ' || pgv.esc(v_opt) || '</label>';
  END LOOP;
  RETURN v_html || '</fieldset>';
END;
$function$;
