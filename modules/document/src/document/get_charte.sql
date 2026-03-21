CREATE OR REPLACE FUNCTION document.get_charte(p_id text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_c document.charte;
  v_body text;
  v_k text;
  v_v text;
BEGIN
  SELECT * INTO v_c FROM document.charte WHERE id = p_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_c IS NULL THEN RETURN pgv.empty(pgv.t('document.err_charte_not_found')); END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('document.brand'), '/chartes', pgv.esc(v_c.name)]);

  IF v_c.description IS NOT NULL THEN
    v_body := v_body || '<p>' || pgv.esc(v_c.description) || '</p>';
  END IF;

  -- Colors
  v_body := v_body || '<h3>Couleurs</h3>'
    || pgv.grid(VARIADIC ARRAY[
      pgv.stat('Background', pgv.badge(v_c.color_bg, v_c.color_bg)),
      pgv.stat('Main', pgv.badge(v_c.color_main, v_c.color_main)),
      pgv.stat('Accent', pgv.badge(v_c.color_accent, v_c.color_accent)),
      pgv.stat('Text', pgv.badge(v_c.color_text, v_c.color_text)),
      pgv.stat('Text light', pgv.badge(v_c.color_text_light, v_c.color_text_light)),
      pgv.stat('Border', pgv.badge(v_c.color_border, v_c.color_border))
    ]);

  -- Color extra
  IF v_c.color_extra != '{}'::jsonb THEN
    v_body := v_body || '<h4>Couleurs libres</h4><p>';
    FOR v_k, v_v IN SELECT key, value #>> '{}' FROM jsonb_each(v_c.color_extra)
    LOOP
      v_body := v_body || pgv.badge(v_k || ' ' || v_v, v_v) || ' ';
    END LOOP;
    v_body := v_body || '</p>';
  END IF;

  -- Fonts
  v_body := v_body || '<h3>Typographie</h3>'
    || pgv.grid(VARIADIC ARRAY[
      pgv.stat('Heading', pgv.esc(v_c.font_heading)),
      pgv.stat('Body', pgv.esc(v_c.font_body))
    ]);

  -- Spacing
  IF v_c.spacing_page IS NOT NULL OR v_c.spacing_section IS NOT NULL THEN
    v_body := v_body || '<h3>Spacing</h3>'
      || pgv.grid(VARIADIC ARRAY[
        pgv.stat('Page', COALESCE(v_c.spacing_page, '—')),
        pgv.stat('Section', COALESCE(v_c.spacing_section, '—')),
        pgv.stat('Gap', COALESCE(v_c.spacing_gap, '—')),
        pgv.stat('Card', COALESCE(v_c.spacing_card, '—'))
      ]);
  END IF;

  -- Shadow / Radius
  IF v_c.shadow_card IS NOT NULL OR v_c.radius_card IS NOT NULL THEN
    v_body := v_body || '<h3>Shadow / Radius</h3>'
      || pgv.grid(VARIADIC ARRAY[
        pgv.stat('Card shadow', COALESCE(v_c.shadow_card, '—')),
        pgv.stat('Elevated shadow', COALESCE(v_c.shadow_elevated, '—')),
        pgv.stat('Card radius', COALESCE(v_c.radius_card, '—'))
      ]);
  END IF;

  -- Voice
  IF v_c.voice_personality IS NOT NULL THEN
    v_body := v_body || '<h3>Voice</h3><p>'
      || '<strong>Personnalité:</strong> ' || array_to_string(v_c.voice_personality, ', ') || '<br>'
      || '<strong>Formalité:</strong> ' || COALESCE(v_c.voice_formality, '—')
      || '</p>';
    IF v_c.voice_do IS NOT NULL THEN
      v_body := v_body || '<p><strong>Do:</strong> ' || array_to_string(v_c.voice_do, ', ') || '</p>';
    END IF;
    IF v_c.voice_dont IS NOT NULL THEN
      v_body := v_body || '<p><strong>Don''t:</strong> ' || array_to_string(v_c.voice_dont, ', ') || '</p>';
    END IF;
  END IF;

  -- Actions
  v_body := v_body || '<p>'
    || pgv.action('post_charte_delete', pgv.t('document.btn_delete'), jsonb_build_object('p_name', v_c.name), 'Supprimer cette charte ?', 'danger')
    || '</p>';

  RETURN v_body;
END;
$function$;
