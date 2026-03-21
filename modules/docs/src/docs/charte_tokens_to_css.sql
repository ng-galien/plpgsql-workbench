CREATE OR REPLACE FUNCTION docs.charte_tokens_to_css(p_charte_id text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SET "api.expose" TO 'mcp'
AS $function$
DECLARE
  v_c docs.charte;
  v_css text;
  v_imports text := '';
  v_fonts text[];
  v_f text;
  v_k text;
  v_v text;
  v_generics constant text[] := ARRAY['serif','sans-serif','monospace','cursive','fantasy','system-ui','ui-serif','ui-sans-serif','ui-monospace','ui-rounded'];
BEGIN
  SELECT * INTO v_c FROM docs.charte WHERE id = p_charte_id;
  IF v_c IS NULL THEN RETURN NULL; END IF;

  v_css := ':root {' || chr(10);

  -- Colors
  v_css := v_css || '  --charte-color-bg: ' || v_c.color_bg || ';' || chr(10);
  v_css := v_css || '  --charte-color-main: ' || v_c.color_main || ';' || chr(10);
  v_css := v_css || '  --charte-color-accent: ' || v_c.color_accent || ';' || chr(10);
  v_css := v_css || '  --charte-color-text: ' || v_c.color_text || ';' || chr(10);
  v_css := v_css || '  --charte-color-text-light: ' || v_c.color_text_light || ';' || chr(10);
  v_css := v_css || '  --charte-color-border: ' || v_c.color_border || ';' || chr(10);

  -- Color extra
  FOR v_k, v_v IN SELECT key, value #>> '{}' FROM jsonb_each(v_c.color_extra)
  LOOP
    v_css := v_css || '  --charte-color-' || v_k || ': ' || v_v || ';' || chr(10);
  END LOOP;

  -- Fonts
  v_css := v_css || '  --charte-font-heading: ' || quote_literal(v_c.font_heading) || ';' || chr(10);
  v_css := v_css || '  --charte-font-body: ' || quote_literal(v_c.font_body) || ';' || chr(10);

  -- Spacing
  IF v_c.spacing_page IS NOT NULL THEN v_css := v_css || '  --charte-spacing-page: ' || v_c.spacing_page || ';' || chr(10); END IF;
  IF v_c.spacing_section IS NOT NULL THEN v_css := v_css || '  --charte-spacing-section: ' || v_c.spacing_section || ';' || chr(10); END IF;
  IF v_c.spacing_gap IS NOT NULL THEN v_css := v_css || '  --charte-spacing-gap: ' || v_c.spacing_gap || ';' || chr(10); END IF;
  IF v_c.spacing_card IS NOT NULL THEN v_css := v_css || '  --charte-spacing-card: ' || v_c.spacing_card || ';' || chr(10); END IF;

  -- Shadow
  IF v_c.shadow_card IS NOT NULL THEN v_css := v_css || '  --charte-shadow-card: ' || v_c.shadow_card || ';' || chr(10); END IF;
  IF v_c.shadow_elevated IS NOT NULL THEN v_css := v_css || '  --charte-shadow-elevated: ' || v_c.shadow_elevated || ';' || chr(10); END IF;

  -- Radius
  IF v_c.radius_card IS NOT NULL THEN v_css := v_css || '  --charte-radius-card: ' || v_c.radius_card || ';' || chr(10); END IF;

  v_css := v_css || '}';

  -- Google Fonts @import
  v_fonts := ARRAY[v_c.font_heading, v_c.font_body];
  FOREACH v_f IN ARRAY v_fonts
  LOOP
    IF v_f IS NOT NULL AND NOT (lower(v_f) = ANY(v_generics)) THEN
      v_imports := v_imports || '@import url(''https://fonts.googleapis.com/css2?family=' || replace(v_f, ' ', '+') || ':wght@400;700&display=swap'');' || chr(10);
    END IF;
  END LOOP;

  -- Deduplicate if heading = body
  IF v_c.font_heading = v_c.font_body THEN
    v_imports := '@import url(''https://fonts.googleapis.com/css2?family=' || replace(v_c.font_heading, ' ', '+') || ':wght@400;700&display=swap'');' || chr(10);
  END IF;

  IF v_imports != '' THEN
    RETURN v_imports || chr(10) || v_css;
  END IF;

  RETURN v_css;
END;
$function$;
