CREATE OR REPLACE FUNCTION document.get_libraries()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  v_cnt int;
  r record;
BEGIN
  SELECT count(*)::int INTO v_cnt FROM document.library WHERE tenant_id = current_setting('app.tenant_id', true);

  v_body := '<h2>' || pgv.t('document.title_libraries') || '</h2>';

  IF v_cnt = 0 THEN
    RETURN v_body || pgv.empty(pgv.t('document.empty_no_libraries'), pgv.t('document.empty_first_library'));
  END IF;

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT l.id, l.name, l.description,
           (SELECT count(*) FROM document.library_asset la WHERE la.library_id = l.id) AS asset_cnt,
           (SELECT count(*) FROM document.document d WHERE d.library_id = l.id) AS doc_cnt
    FROM document.library l
    WHERE l.tenant_id = current_setting('app.tenant_id', true)
    ORDER BY l.name
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="/library?p_id=%s">%s</a>', r.id, pgv.esc(r.name)),
      COALESCE(r.description, '—'),
      r.asset_cnt::text,
      r.doc_cnt::text
    ];
  END LOOP;

  v_body := v_body || pgv.md_table(
    ARRAY[pgv.t('document.col_name'), 'Description', 'Assets', 'Docs'],
    v_rows, 20
  );

  RETURN v_body;
END;
$function$;
