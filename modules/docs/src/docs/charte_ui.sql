CREATE OR REPLACE FUNCTION docs.charte_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_c docs.charte;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('docs.title_chartes')),
        pgv.ui_table('chartes', jsonb_build_array(
          pgv.ui_col('name', pgv.t('docs.col_name'), pgv.ui_link('{name}', '/docs/chartes/{slug}')),
          pgv.ui_col('description', pgv.t('docs.col_description')),
          pgv.ui_col('color_bg', pgv.t('docs.col_bg'), pgv.ui_color('{color_bg}')),
          pgv.ui_col('color_main', pgv.t('docs.col_main'), pgv.ui_color('{color_main}')),
          pgv.ui_col('color_accent', pgv.t('docs.col_accent'), pgv.ui_color('{color_accent}')),
          pgv.ui_col('font_heading', pgv.t('docs.col_heading_font')),
          pgv.ui_col('font_body', pgv.t('docs.col_body_font'))
        ))
      ),
      'datasources', jsonb_build_object(
        'chartes', pgv.ui_datasource('docs://charte', 20, true, 'name')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_c FROM docs.charte WHERE slug = p_slug AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link(pgv.t('docs.title_chartes'), '/docs/chartes'),
        pgv.ui_heading(v_c.name)
      ),
      pgv.ui_text(coalesce(v_c.description, '')),

      -- Palette
      pgv.ui_heading(pgv.t('docs.title_palette'), 3),
      pgv.ui_row(
        pgv.ui_color(v_c.color_bg),
        pgv.ui_color(v_c.color_main),
        pgv.ui_color(v_c.color_accent),
        pgv.ui_color(v_c.color_text),
        pgv.ui_color(v_c.color_text_light),
        pgv.ui_color(v_c.color_border)
      ),

      -- Typography
      pgv.ui_heading(pgv.t('docs.title_typography'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('docs.label_heading_font') || ': ' || v_c.font_heading),
        pgv.ui_text(pgv.t('docs.label_body_font') || ': ' || v_c.font_body)
      ),

      -- Spacing
      pgv.ui_heading(pgv.t('docs.title_spacing'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('docs.label_page') || ': ' || coalesce(v_c.spacing_page, '—')),
        pgv.ui_text(pgv.t('docs.label_section') || ': ' || coalesce(v_c.spacing_section, '—')),
        pgv.ui_text(pgv.t('docs.label_gap') || ': ' || coalesce(v_c.spacing_gap, '—')),
        pgv.ui_text(pgv.t('docs.label_card') || ': ' || coalesce(v_c.spacing_card, '—'))
      ),

      -- Voice
      pgv.ui_heading(pgv.t('docs.title_voice'), 3),
      pgv.ui_row(
        pgv.ui_badge(coalesce(v_c.voice_formality, '—')),
        pgv.ui_text(coalesce(array_to_string(v_c.voice_personality, ', '), ''))
      )
    )
  );
END;
$function$;
