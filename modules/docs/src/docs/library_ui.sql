CREATE OR REPLACE FUNCTION docs.library_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_l docs.library;
  v_asset_cnt int;
  v_doc_cnt int;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('docs.title_libraries')),
        pgv.ui_table('libraries', jsonb_build_array(
          pgv.ui_col('name', pgv.t('docs.col_name'), pgv.ui_link('{name}', '/docs/libraries/{slug}')),
          pgv.ui_col('description', pgv.t('docs.col_description')),
          pgv.ui_col('asset_count', pgv.t('docs.col_asset_count'), pgv.ui_badge('{asset_count}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'libraries', pgv.ui_datasource('docs://library', 20, true, 'name')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_l FROM docs.library WHERE slug = p_slug AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT count(*)::int INTO v_asset_cnt FROM docs.library_asset WHERE library_id = v_l.id;
  SELECT count(*)::int INTO v_doc_cnt FROM docs.document WHERE library_id = v_l.id AND tenant_id = current_setting('app.tenant_id', true);

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link(pgv.t('docs.title_libraries'), '/docs/libraries'),
        pgv.ui_heading(v_l.name)
      ),
      pgv.ui_text(coalesce(v_l.description, '')),

      -- Stats
      pgv.ui_row(
        pgv.ui_stat(v_asset_cnt::text, pgv.t('docs.stat_assets')),
        pgv.ui_stat(v_doc_cnt::text, pgv.t('docs.stat_documents'))
      )
    )
  );
END;
$function$;
