CREATE OR REPLACE FUNCTION pgv.nav(p_brand text, p_items jsonb, p_current text)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE v_html text; v_item jsonb; v_href text; v_label text;
BEGIN
  v_html := '<nav class="container-fluid"><ul><li><strong>' || pgv.esc(p_brand) || '</strong></li></ul><ul>';
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_href  := v_item->>'href';
    v_label := v_item->>'label';
    IF v_href = p_current THEN
      v_html := v_html || format('<li><a href="%s" aria-current="page">%s</a></li>', v_href, pgv.esc(v_label));
    ELSE
      v_html := v_html || format('<li><a href="%s">%s</a></li>', v_href, pgv.esc(v_label));
    END IF;
  END LOOP;
  v_html := v_html || '</ul><ul><li>'
    || '<button class="pgv-theme-toggle" data-toggle-theme title="Changer de theme">'
    || '&#x263E;</button></li></ul></nav>';
  RETURN v_html;
END;
$function$;
