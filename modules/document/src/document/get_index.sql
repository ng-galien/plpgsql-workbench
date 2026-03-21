CREATE OR REPLACE FUNCTION document.get_index()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_nb_docs int;
  v_nb_chartes int;
  v_nb_pages int;
  v_nb_draft int;
  v_rows text[];
  r record;
BEGIN
  -- Stats
  SELECT count(*)::int INTO v_nb_docs FROM document.document;
  SELECT count(*)::int INTO v_nb_chartes FROM document.charte;
  SELECT count(*)::int INTO v_nb_pages FROM document.page;
  SELECT count(*)::int INTO v_nb_draft FROM document.document WHERE status = 'draft';

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('document.stat_documents'), v_nb_docs::text),
    pgv.stat(pgv.t('document.stat_chartes'), v_nb_chartes::text),
    pgv.stat(pgv.t('document.stat_pages'), v_nb_pages::text),
    pgv.stat(pgv.t('document.stat_draft'), v_nb_draft::text)
  ]);

  -- Document list
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT d.id, d.name, d.category, d.format, d.orientation, d.status,
           c.name AS charte_name,
           (SELECT count(*) FROM document.page p WHERE p.doc_id = d.id) AS nb_pages,
           d.updated_at
    FROM document.document d
    LEFT JOIN document.charte c ON c.id = d.charte_id
    ORDER BY d.updated_at DESC
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="/document?p_id=%s">%s</a>', r.id, pgv.esc(r.name)),
      r.category,
      r.format || ' ' || r.orientation,
      COALESCE(r.charte_name, '—'),
      pgv.badge(r.status, CASE r.status WHEN 'draft' THEN 'secondary' WHEN 'generated' THEN 'primary' WHEN 'signed' THEN 'success' ELSE 'muted' END),
      r.nb_pages::text,
      to_char(r.updated_at, 'DD/MM/YY')
    ];
  END LOOP;

  IF v_nb_docs = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('document.empty_no_documents'), pgv.t('document.empty_first_document'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('document.col_name'), pgv.t('document.col_category'), pgv.t('document.col_format'), pgv.t('document.col_charte'), pgv.t('document.col_status'), pgv.t('document.col_pages'), pgv.t('document.col_updated')],
      v_rows, 20
    );
  END IF;

  RETURN v_body;
END;
$function$;
