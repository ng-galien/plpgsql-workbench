CREATE OR REPLACE FUNCTION document.get_document(p_id text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_d document.document;
  v_body text;
  v_charte_name text;
  v_rows text[];
  r record;
BEGIN
  SELECT * INTO v_d FROM document.document WHERE id = p_id AND tenant_id = current_setting('app.tenant_id', true);
  IF v_d IS NULL THEN RETURN pgv.empty(pgv.t('document.err_not_found')); END IF;

  IF v_d.charte_id IS NOT NULL THEN
    SELECT name INTO v_charte_name FROM document.charte WHERE id = v_d.charte_id;
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('document.brand'), '/', pgv.esc(v_d.name)]);

  v_body := v_body || '<p><small>'
    || v_d.format || ' ' || v_d.orientation
    || ' · ' || v_d.width::int::text || '×' || v_d.height::int::text
    || ' · ' || pgv.badge(v_d.status, CASE v_d.status WHEN 'draft' THEN 'secondary' WHEN 'generated' THEN 'primary' WHEN 'signed' THEN 'success' ELSE 'muted' END)
    || CASE WHEN v_charte_name IS NOT NULL THEN ' · Charte: ' || pgv.esc(v_charte_name) ELSE '' END
    || '</small></p>';

  -- Pages table
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT page_index, name, length(html) AS html_len,
           (SELECT count(*)::int FROM regexp_matches(html, 'data-id="[^"]*"', 'g')) AS elem_cnt
    FROM document.page WHERE doc_id = p_id ORDER BY page_index
  LOOP
    v_rows := v_rows || ARRAY[
      r.page_index::text,
      pgv.esc(r.name),
      r.elem_cnt::text,
      pg_size_pretty(r.html_len::bigint)
    ];
  END LOOP;

  IF cardinality(v_rows) > 0 THEN
    v_body := v_body || '<h3>Pages</h3>'
      || pgv.md_table(ARRAY['#', 'Nom', 'Éléments', 'Taille'], v_rows, 20);
  END IF;

  -- Actions
  v_body := v_body || '<p>'
    || pgv.action('post_doc_duplicate', pgv.t('document.btn_duplicate'), jsonb_build_object('p_source_id', p_id), 'Dupliquer ce document ?', 'outline')
    || ' '
    || pgv.action('post_doc_delete', pgv.t('document.btn_delete'), jsonb_build_object('p_id', p_id), 'Supprimer ce document et toutes ses pages ?', 'danger')
    || '</p>';

  RETURN v_body;
END;
$function$;
