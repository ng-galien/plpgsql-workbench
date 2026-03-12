CREATE OR REPLACE FUNCTION pgv.timeline(p_items jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_html text := '<div class="pgv-tl">';
  v_item jsonb;
  v_badge text;
  v_dot_cls text;
BEGIN
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_badge := coalesce(v_item->>'badge', '');
    v_dot_cls := 'pgv-tl-dot' || CASE WHEN v_badge <> '' THEN ' pgv-tl-dot-' || v_badge ELSE '' END;

    v_html := v_html || '<div class="pgv-tl-item">'
      || '<span class="' || v_dot_cls || '"></span>';

    IF v_item->>'date' IS NOT NULL THEN
      v_html := v_html || '<div class="pgv-tl-date">' || pgv.esc(v_item->>'date') || '</div>';
    END IF;

    v_html := v_html || '<div class="pgv-tl-label">' || pgv.esc(v_item->>'label') || '</div>';

    IF v_item->>'detail' IS NOT NULL THEN
      v_html := v_html || '<div class="pgv-tl-detail">' || pgv.esc(v_item->>'detail') || '</div>';
    END IF;

    v_html := v_html || '</div>';
  END LOOP;

  RETURN v_html || '</div>';
END;
$function$;
