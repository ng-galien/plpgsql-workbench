CREATE OR REPLACE FUNCTION stock.get_movements()
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
    SELECT m.id, m.created_at, a.reference, a.description, w.name AS warehouse_name,
           m.type, m.quantity, m.unit_price, m.reference AS ref_doc,
           ww.name AS dest_name
    FROM stock.movement m
    JOIN stock.article a ON a.id = m.article_id
    JOIN stock.warehouse w ON w.id = m.warehouse_id
    LEFT JOIN stock.warehouse ww ON ww.id = m.destination_warehouse_id
    ORDER BY m.created_at DESC
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.created_at, 'DD/MM/YY HH24:MI'),
      format('<a href="%s">%s</a>', pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)), pgv.esc(r.reference)),
      pgv.esc(r.description),
      pgv.esc(r.warehouse_name) || CASE WHEN r.dest_name IS NOT NULL THEN ' -> ' || pgv.esc(r.dest_name) ELSE '' END,
      pgv.badge(r.type, CASE r.type WHEN 'entry' THEN 'success' WHEN 'exit' THEN 'danger' WHEN 'transfer' THEN 'info' WHEN 'inventory' THEN 'warning' END),
      r.quantity::text, coalesce(r.ref_doc, '')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_body := pgv.empty(pgv.t('stock.empty_no_mouvement'), pgv.t('stock.empty_first_mouvement_short'));
  ELSE
    v_body := pgv.md_table(
      ARRAY[pgv.t('stock.col_date'), pgv.t('stock.col_ref'), pgv.t('stock.col_article'), pgv.t('stock.col_depot'), pgv.t('stock.col_type'), pgv.t('stock.col_qty'), pgv.t('stock.col_ref_doc')],
      v_rows, 20);
  END IF;

  v_body := v_body || '<p>' || pgv.form_dialog(
    'dlg-new-mvt', pgv.t('stock.btn_nouveau_mvt'), '', 'post_movement_save',
    NULL, NULL, pgv.call_ref('get_movement_form')
  ) || '</p>';

  RETURN v_body;
END;
$function$;
