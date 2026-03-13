CREATE OR REPLACE FUNCTION document.get_templates(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_total int;
  v_rows  text[];
  v_body  text;
  r       record;
BEGIN
  SELECT count(*)::int INTO v_total FROM document.template WHERE tenant_id = current_setting('app.tenant_id', true);

  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('document.stat_templates'), v_total::text)
  ]);

  IF v_total = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('document.empty_no_template'), pgv.t('document.empty_first_template'));
  ELSE
    v_rows := ARRAY[]::text[];
    FOR r IN
      SELECT t.id, t.name, t.doc_type, t.format, t.orientation, t.is_default, t.version, t.created_at
      FROM document.template t
      WHERE t.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY t.doc_type, t.name
    LOOP
      v_rows := v_rows || ARRAY[
        pgv.esc(r.name),
        r.doc_type,
        r.format || ' ' || r.orientation,
        CASE WHEN r.is_default THEN pgv.t('document.yes') ELSE pgv.t('document.no') END,
        r.version::text,
        to_char(r.created_at, 'DD/MM/YYYY')
      ];
    END LOOP;

    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('document.col_name'), pgv.t('document.col_doc_type'), pgv.t('document.col_format'), pgv.t('document.col_default'), pgv.t('document.col_version'), pgv.t('document.col_created')],
      v_rows,
      20
    );
  END IF;

  RETURN v_body;
END;
$function$;
