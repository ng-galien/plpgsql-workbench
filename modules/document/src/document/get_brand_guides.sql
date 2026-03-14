CREATE OR REPLACE FUNCTION document.get_brand_guides(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_cards text[];
  v_swatches text;
  r record;
BEGIN
  v_body := '';
  v_cards := ARRAY[]::text[];

  FOR r IN
    SELECT * FROM document.brand_guide
    WHERE tenant_id = current_setting('app.tenant_id', true)
    ORDER BY name
  LOOP
    -- Color swatches preview
    v_swatches := '<div class="grid">'
      || '<div><small>Principal</small><br><svg width="40" height="20"><rect width="40" height="20" fill="' || pgv.esc(r.primary_color) || '" rx="3"/></svg></div>'
      || '<div><small>Secondaire</small><br><svg width="40" height="20"><rect width="40" height="20" fill="' || pgv.esc(COALESCE(r.secondary_color, '#fff')) || '" rx="3" stroke="#ddd"/></svg></div>'
      || CASE WHEN r.accent_color IS NOT NULL THEN '<div><small>Accent</small><br><svg width="40" height="20"><rect width="40" height="20" fill="' || pgv.esc(r.accent_color) || '" rx="3"/></svg></div>' ELSE '' END
      || '<div><small>Texte</small><br><svg width="40" height="20"><rect width="40" height="20" fill="' || pgv.esc(COALESCE(r.text_color, '#000')) || '" rx="3"/></svg></div>'
      || '</div>'
      || '<p><small>' || pgv.esc(r.font_title) || ' ' || pgv.esc(r.font_title_weight) || ' ' || r.font_title_size::text || 'mm · '
      || pgv.esc(r.font_body) || ' ' || pgv.esc(r.font_body_weight) || ' ' || r.font_body_size::text || 'mm</small></p>';

    v_cards := v_cards || pgv.card(r.name, v_swatches);
  END LOOP;

  IF cardinality(v_cards) = 0 THEN
    v_body := pgv.empty(pgv.t('document.empty_no_brand_guide'), pgv.t('document.empty_first_brand_guide'));
  ELSE
    v_body := pgv.grid(VARIADIC v_cards);
  END IF;

  RETURN v_body;
END;
$function$;
