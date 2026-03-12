CREATE OR REPLACE FUNCTION pgv.select_search(p_name text, p_label text, p_rpc text, p_placeholder text DEFAULT ''::text, p_value text DEFAULT NULL::text, p_display text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN '<label>' || pgv.esc(p_label)
    || '<div class="pgv-ss" data-ss-rpc="' || pgv.esc(p_rpc) || '">'
    || '<input type="text" class="pgv-ss-input"'
    || ' placeholder="' || pgv.esc(coalesce(p_placeholder, '')) || '"'
    || CASE WHEN p_display IS NOT NULL THEN ' value="' || pgv.esc(p_display) || '"' ELSE '' END
    || ' autocomplete="off">'
    || '<input type="hidden" name="' || pgv.esc(p_name) || '"'
    || CASE WHEN p_value IS NOT NULL THEN ' value="' || pgv.esc(p_value) || '"' ELSE '' END
    || '>'
    || '<div class="pgv-ss-results"></div>'
    || '</div></label>';
END;
$function$;
