CREATE OR REPLACE FUNCTION stock.get_warehouse(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_wh stock.warehouse;
  v_body text;
  v_rows text[];
  r record;
BEGIN
  SELECT * INTO v_wh FROM stock.warehouse WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.empty(pgv.t('stock.empty_depot_not_found'), ''); END IF;

  v_body := format('<p><strong>%s</strong> %s | <strong>%s</strong> %s | <strong>%s</strong> %s</p>',
    pgv.t('stock.label_type'), pgv.badge(v_wh.type, NULL),
    pgv.t('stock.label_adresse'), coalesce(pgv.esc(v_wh.address), '—'),
    pgv.t('stock.label_actif'), CASE WHEN v_wh.active THEN pgv.t('stock.yes') ELSE pgv.t('stock.no') END
  );

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.description, a.unit, stock._current_stock(a.id, p_id) AS qty
    FROM stock.article a
    WHERE a.active
      AND EXISTS (SELECT 1 FROM stock.movement m WHERE m.article_id = a.id AND m.warehouse_id = p_id)
    ORDER BY a.description
  LOOP
    IF r.qty <> 0 THEN
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>', pgv.call_ref('get_article', jsonb_build_object('p_id', r.id)), pgv.esc(r.reference)),
        pgv.esc(r.description), r.qty::text || ' ' || r.unit
      ];
    END IF;
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('stock.title_contenu') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_ref'), pgv.t('stock.col_designation'), pgv.t('stock.col_quantite')], v_rows);
  ELSE
    v_body := v_body || pgv.empty(pgv.t('stock.empty_depot_vide'), '');
  END IF;

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT m.created_at, a.description, m.type, m.quantity, m.reference
    FROM stock.movement m JOIN stock.article a ON a.id = m.article_id
    WHERE m.warehouse_id = p_id ORDER BY m.created_at DESC LIMIT 20
  LOOP
    v_rows := v_rows || ARRAY[
      to_char(r.created_at, 'DD/MM HH24:MI'), pgv.esc(r.description),
      pgv.badge(r.type, CASE r.type WHEN 'entry' THEN 'success' WHEN 'exit' THEN 'danger' WHEN 'transfer' THEN 'info' WHEN 'inventory' THEN 'warning' END),
      r.quantity::text, coalesce(r.reference, '')
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('stock.title_mvt_recents') || '</h3>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_date'), pgv.t('stock.col_article'), pgv.t('stock.col_type'), pgv.t('stock.col_qty'), pgv.t('stock.col_ref')], v_rows, 10);
  END IF;

  v_body := v_body || '<p>' || pgv.form_dialog(
    'dlg-edit-wh-' || p_id, pgv.t('stock.btn_modifier'), '', 'post_warehouse_save',
    pgv.t('stock.btn_modifier'), 'outline',
    pgv.call_ref('get_warehouse_form', jsonb_build_object('p_id', p_id))
  ) || '</p>';

  RETURN v_body;
END;
$function$;
