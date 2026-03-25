CREATE OR REPLACE FUNCTION docs.get_charter(p_id text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE v_c docs.charter; v_body text; v_k text; v_v text;
BEGIN
  SELECT * INTO v_c FROM docs.charter WHERE id = p_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_c IS NULL THEN RETURN pgv.empty(pgv.t('docs.err_charte_not_found')); END IF;
  v_body := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('docs.brand'), '/charters', pgv.esc(v_c.name)]);
  IF v_c.description IS NOT NULL THEN v_body := v_body || '<p>' || pgv.esc(v_c.description) || '</p>'; END IF;
  v_body := v_body || '<h3>Colors</h3>' || pgv.grid(VARIADIC ARRAY[pgv.stat('Background', pgv.badge(v_c.color_bg, v_c.color_bg)), pgv.stat('Main', pgv.badge(v_c.color_main, v_c.color_main)), pgv.stat('Accent', pgv.badge(v_c.color_accent, v_c.color_accent)), pgv.stat('Text', pgv.badge(v_c.color_text, v_c.color_text)), pgv.stat('Text light', pgv.badge(v_c.color_text_light, v_c.color_text_light)), pgv.stat('Border', pgv.badge(v_c.color_border, v_c.color_border))]);
  IF v_c.color_extra != '{}'::jsonb THEN
    v_body := v_body || '<h4>Extra colors</h4><p>';
    FOR v_k, v_v IN SELECT key, value #>> '{}' FROM jsonb_each(v_c.color_extra) LOOP v_body := v_body || pgv.badge(v_k || ' ' || v_v, v_v) || ' '; END LOOP;
    v_body := v_body || '</p>';
  END IF;
  v_body := v_body || '<h3>Typography</h3>' || pgv.grid(VARIADIC ARRAY[pgv.stat('Heading', pgv.esc(v_c.font_heading)), pgv.stat('Body', pgv.esc(v_c.font_body))]);
  IF v_c.spacing_page IS NOT NULL OR v_c.spacing_section IS NOT NULL THEN
    v_body := v_body || '<h3>Spacing</h3>' || pgv.grid(VARIADIC ARRAY[pgv.stat('Page', COALESCE(v_c.spacing_page, '—')), pgv.stat('Section', COALESCE(v_c.spacing_section, '—')), pgv.stat('Gap', COALESCE(v_c.spacing_gap, '—')), pgv.stat('Card', COALESCE(v_c.spacing_card, '—'))]);
  END IF;
  IF v_c.shadow_card IS NOT NULL OR v_c.radius_card IS NOT NULL THEN
    v_body := v_body || '<h3>Shadow / Radius</h3>' || pgv.grid(VARIADIC ARRAY[pgv.stat('Card shadow', COALESCE(v_c.shadow_card, '—')), pgv.stat('Elevated shadow', COALESCE(v_c.shadow_elevated, '—')), pgv.stat('Card radius', COALESCE(v_c.radius_card, '—'))]);
  END IF;
  IF v_c.voice_personality IS NOT NULL THEN
    v_body := v_body || '<h3>Voice</h3><p><strong>Personality:</strong> ' || array_to_string(v_c.voice_personality, ', ') || '<br><strong>Formality:</strong> ' || COALESCE(v_c.voice_formality, '—') || '</p>';
    IF v_c.voice_do IS NOT NULL THEN v_body := v_body || '<p><strong>Do:</strong> ' || array_to_string(v_c.voice_do, ', ') || '</p>'; END IF;
    IF v_c.voice_dont IS NOT NULL THEN v_body := v_body || '<p><strong>Don''t:</strong> ' || array_to_string(v_c.voice_dont, ', ') || '</p>'; END IF;
  END IF;
  v_body := v_body || '<p>' || pgv.action('post_charter_delete', pgv.t('docs.action_delete'), jsonb_build_object('p_id', v_c.id), pgv.t('docs.confirm_delete'), 'danger') || '</p>';
  RETURN v_body;
END;
$function$;
