CREATE OR REPLACE FUNCTION docs.get_chartes()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  v_cnt int;
  r record;
BEGIN
  SELECT count(*)::int INTO v_cnt FROM docs.charte WHERE tenant_id = current_setting('app.tenant_id', true);

  v_body := '<h2>' || pgv.t('docs.title_chartes') || '</h2>';

  IF v_cnt = 0 THEN
    RETURN v_body || pgv.empty(pgv.t('docs.empty_no_chartes'), pgv.t('docs.empty_first_charte'));
  END IF;

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT id, name, description, color_bg, color_main, color_accent, font_heading, font_body,
           (SELECT count(*) FROM docs.document d WHERE d.charte_id = c.id) AS doc_cnt
    FROM docs.charte c
    WHERE tenant_id = current_setting('app.tenant_id', true)
    ORDER BY name
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="/charte?p_id=%s">%s</a>', r.id, pgv.esc(r.name)),
      COALESCE(r.description, '—'),
      pgv.badge(' ', r.color_bg) || ' ' || pgv.badge(' ', r.color_main) || ' ' || pgv.badge(' ', r.color_accent),
      r.font_heading || ' / ' || r.font_body,
      r.doc_cnt::text
    ];
  END LOOP;

  v_body := v_body || pgv.md_table(
    ARRAY[pgv.t('docs.col_name'), 'Description', pgv.t('docs.col_colors'), pgv.t('docs.col_fonts'), 'Docs'],
    v_rows, 20
  );

  RETURN v_body;
END;
$function$;
