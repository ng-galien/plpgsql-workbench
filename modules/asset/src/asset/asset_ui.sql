CREATE OR REPLACE FUNCTION asset.asset_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_a RECORD;
BEGIN
  -- List mode: no slug
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('asset.nav_assets')),
        pgv.ui_table('assets', jsonb_build_array(
          pgv.ui_col('title', pgv.t('asset.col_title'), pgv.ui_link('{title}', '/asset/asset/{id}')),
          pgv.ui_col('filename', pgv.t('asset.col_filename')),
          pgv.ui_col('mime_type', pgv.t('asset.col_mime')),
          pgv.ui_col('status', pgv.t('asset.col_status'), pgv.ui_badge('{status}')),
          pgv.ui_col('orientation', pgv.t('asset.field_orientation')),
          pgv.ui_col('credit', pgv.t('asset.field_credit'))
        ))
      ),
      'datasources', jsonb_build_object(
        'assets', pgv.ui_datasource('asset://asset', 20, true, 'created_at')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_a FROM asset.asset WHERE id::text = p_slug AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link('← ' || pgv.t('asset.nav_assets'), '/asset/'),
        pgv.ui_heading(COALESCE(v_a.title, v_a.filename))
      ),
      pgv.ui_row(
        pgv.ui_badge(v_a.status, CASE v_a.status WHEN 'classified' THEN 'success' WHEN 'to_classify' THEN 'warning' ELSE 'info' END),
        pgv.ui_text(v_a.mime_type),
        pgv.ui_text(CASE WHEN v_a.width IS NOT NULL THEN v_a.width::text || ' × ' || v_a.height::text ELSE '' END)
      ),
      pgv.ui_heading(pgv.t('asset.field_description'), 3),
      pgv.ui_text(COALESCE(v_a.description, '—')),
      pgv.ui_heading(pgv.t('asset.section_metadata'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('asset.field_filename') || ': ' || v_a.filename),
        pgv.ui_text(pgv.t('asset.field_orientation') || ': ' || COALESCE(v_a.orientation, '—')),
        pgv.ui_text(pgv.t('asset.field_season') || ': ' || COALESCE(v_a.season, '—'))
      ),
      pgv.ui_row(
        pgv.ui_text(pgv.t('asset.field_credit') || ': ' || COALESCE(v_a.credit, '—')),
        pgv.ui_text(pgv.t('asset.field_usage_hint') || ': ' || COALESCE(v_a.usage_hint, '—'))
      ),
      pgv.ui_heading(pgv.t('asset.field_colors'), 3),
      CASE WHEN cardinality(v_a.colors) > 0 THEN
        pgv.ui_row(VARIADIC ARRAY(SELECT pgv.ui_color(c) FROM unnest(v_a.colors) AS c))
      ELSE
        pgv.ui_text('—')
      END,
      pgv.ui_heading(pgv.t('asset.field_tags'), 3),
      CASE WHEN cardinality(v_a.tags) > 0 THEN
        pgv.ui_row(VARIADIC ARRAY(SELECT pgv.ui_badge(t) FROM unnest(v_a.tags) AS t))
      ELSE
        pgv.ui_text('—')
      END
    )
  );
END;
$function$;
