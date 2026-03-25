CREATE OR REPLACE FUNCTION stock.get_warehouses()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_rows text[];
  r record;
BEGIN
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT w.id, w.name, w.type, w.address, w.active,
           (SELECT count(DISTINCT m.article_id) FROM stock.movement m WHERE m.warehouse_id = w.id)::int AS nb_articles
    FROM stock.warehouse w ORDER BY w.name
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_warehouse', jsonb_build_object('p_id', r.id)), pgv.esc(r.name)),
      pgv.badge(r.type, CASE r.type WHEN 'workshop' THEN 'success' WHEN 'job_site' THEN 'warning' WHEN 'vehicle' THEN 'info' WHEN 'storage' THEN NULL END),
      coalesce(r.address, '—'), r.nb_articles::text,
      CASE WHEN r.active THEN pgv.t('stock.yes') ELSE pgv.t('stock.no') END
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty(pgv.t('stock.empty_no_depot'), pgv.t('stock.empty_first_depot'));
  ELSE
    v_body := pgv.md_table(
      ARRAY[pgv.t('stock.col_nom'), pgv.t('stock.col_type'), pgv.t('stock.col_adresse'), pgv.t('stock.col_articles'), pgv.t('stock.col_actif')], v_rows);
  END IF;

  v_body := v_body || '<p>' || pgv.form_dialog(
    'dlg-new-wh', pgv.t('stock.btn_nouveau_depot'), '', 'post_warehouse_save',
    NULL, NULL, pgv.call_ref('get_warehouse_form')
  ) || '</p>';

  RETURN v_body;
END;
$function$;
