CREATE OR REPLACE FUNCTION pgv.sel(p_name text, p_label text, p_options jsonb, p_selected text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  v_html text;
  v_opt jsonb;
  v_val text;
  v_lbl text;
BEGIN
  v_html := '<label>' || p_label || '<select name="' || p_name || '">';
  v_html := v_html || '<option value="">--</option>';
  FOR v_opt IN SELECT * FROM jsonb_array_elements(p_options)
  LOOP
    IF jsonb_typeof(v_opt) = 'string' THEN
      v_val := v_opt #>> '{}';
      v_lbl := v_val;
    ELSE
      v_val := v_opt->>'value';
      v_lbl := coalesce(v_opt->>'label', v_val);
    END IF;
    v_html := v_html || '<option value="' || pgv.esc(v_val) || '"'
      || CASE WHEN v_val = p_selected THEN ' selected' ELSE '' END
      || '>' || pgv.esc(v_lbl) || '</option>';
  END LOOP;
  RETURN v_html || '</select></label>';
END;
$function$;
