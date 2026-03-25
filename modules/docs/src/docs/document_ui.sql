CREATE OR REPLACE FUNCTION docs.document_ui(p_slug text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_d docs.document;
  v_page_cnt int;
  v_charter_name text;
BEGIN
  -- List mode
  IF p_slug IS NULL THEN
    RETURN jsonb_build_object(
      'ui', pgv.ui_column(
        pgv.ui_heading(pgv.t('docs.title_documents')),
        pgv.ui_table('documents', jsonb_build_array(
          pgv.ui_col('name', pgv.t('docs.col_name'), pgv.ui_link('{name}', '/docs/document/{slug}')),
          pgv.ui_col('category', pgv.t('docs.col_category'), pgv.ui_badge('{category}')),
          pgv.ui_col('charter_name', pgv.t('docs.col_charte'), pgv.ui_link('{charter_name}', '/docs/charters/{charter_slug}')),
          pgv.ui_col('format', pgv.t('docs.col_format')),
          pgv.ui_col('status', pgv.t('docs.col_status'), pgv.ui_badge('{status}'))
        ))
      ),
      'datasources', jsonb_build_object(
        'documents', pgv.ui_datasource('docs://document', 20, true, 'name')
      )
    );
  END IF;

  -- Detail mode
  SELECT * INTO v_d FROM docs.document WHERE slug = p_slug AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found');
  END IF;

  SELECT count(*)::int INTO v_page_cnt FROM docs.page WHERE doc_id = v_d.id;
  SELECT name INTO v_charter_name FROM docs.charter WHERE id = v_d.charter_id;

  RETURN jsonb_build_object(
    'ui', pgv.ui_column(
      pgv.ui_row(
        pgv.ui_link(pgv.t('docs.title_documents'), '/docs'),
        pgv.ui_heading(v_d.name)
      ),

      -- Canvas
      pgv.ui_heading(pgv.t('docs.title_canvas'), 3),
      pgv.ui_row(
        pgv.ui_badge(v_d.format),
        pgv.ui_badge(v_d.orientation),
        pgv.ui_text(v_d.width || ' × ' || v_d.height || ' mm'),
        pgv.ui_badge(v_d.status)
      ),

      -- Meta
      pgv.ui_heading(pgv.t('docs.title_meta'), 3),
      pgv.ui_row(
        pgv.ui_text(pgv.t('docs.col_category') || ': ' || coalesce(v_d.category, '—')),
        pgv.ui_text(pgv.t('docs.col_charte') || ': ' || coalesce(v_charter_name, '—'))
      ),

      -- Stats
      pgv.ui_row(
        pgv.ui_stat(v_page_cnt::text, pgv.t('docs.stat_pages')),
        pgv.ui_stat(v_d.status, pgv.t('docs.col_status'))
      )
    )
  );
END;
$function$;
