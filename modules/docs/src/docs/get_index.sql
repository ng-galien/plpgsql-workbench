CREATE OR REPLACE FUNCTION docs.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_nb_docs int;
  v_nb_charters int;
  v_nb_pages int;
  v_nb_draft int;
  v_rows text[];
  r record;
BEGIN
  -- Stats
  SELECT count(*)::int INTO v_nb_docs FROM docs.document;
  SELECT count(*)::int INTO v_nb_charters FROM docs.charter;
  SELECT count(*)::int INTO v_nb_pages FROM docs.page;
  SELECT count(*)::int INTO v_nb_draft FROM docs.document WHERE status = 'draft';

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('docs.stat_documents'), v_nb_docs::text),
    pgv.stat(pgv.t('docs.stat_chartes'), v_nb_charters::text),
    pgv.stat(pgv.t('docs.stat_pages'), v_nb_pages::text),
    pgv.stat(pgv.t('docs.stat_draft'), v_nb_draft::text)
  ]);

  -- Document list
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT d.id, d.name, d.category, d.format, d.orientation, d.status,
           c.name AS charter_name,
           (SELECT count(*) FROM docs.page p WHERE p.doc_id = d.id) AS nb_pages,
           d.updated_at
    FROM docs.document d
    LEFT JOIN docs.charter c ON c.id = d.charter_id
    ORDER BY d.updated_at DESC
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="/document?p_id=%s">%s</a>', r.id, pgv.esc(r.name)),
      r.category,
      r.format || ' ' || r.orientation,
      COALESCE(r.charter_name, '—'),
      pgv.badge(r.status, CASE r.status WHEN 'draft' THEN 'secondary' WHEN 'generated' THEN 'primary' WHEN 'signed' THEN 'success' ELSE 'muted' END),
      r.nb_pages::text,
      to_char(r.updated_at, 'DD/MM/YY')
    ];
  END LOOP;

  IF v_nb_docs = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('docs.empty_no_documents'), pgv.t('docs.empty_first_document'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('docs.col_name'), pgv.t('docs.col_category'), pgv.t('docs.col_format'), pgv.t('docs.col_charte'), pgv.t('docs.col_status'), pgv.t('docs.col_pages'), pgv.t('docs.col_updated')],
      v_rows, 20
    );
  END IF;

  RETURN v_body;
END;
$function$;
