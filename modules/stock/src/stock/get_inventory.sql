CREATE OR REPLACE FUNCTION stock.get_inventory(p_warehouse_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  v_warehouse_name text;
  v_rows text[];
  r record;
  v_qty numeric;
  v_form_body text;
BEGIN
  IF p_warehouse_id IS NULL THEN
    v_rows := ARRAY[]::text[];
    FOR r IN
      SELECT w.id, w.name, w.type FROM stock.warehouse w WHERE w.active ORDER BY w.name
    LOOP
      v_rows := v_rows || ARRAY[
        format('<a href="%s">%s</a>',
          pgv.call_ref('get_inventory', jsonb_build_object('p_warehouse_id', r.id)),
          pgv.esc(r.name)),
        pgv.badge(r.type, CASE r.type
          WHEN 'storage' THEN 'info' WHEN 'workshop' THEN 'success' WHEN 'job_site' THEN 'warning' WHEN 'vehicle' THEN 'primary'
        END)
      ];
    END LOOP;

    IF array_length(v_rows, 1) IS NULL THEN
      RETURN pgv.empty(pgv.t('stock.empty_no_depot'), pgv.t('stock.empty_depot_create_first'));
    END IF;

    RETURN '<p>' || pgv.t('stock.title_select_depot') || '</p>' || pgv.md_table(
      ARRAY[pgv.t('stock.col_depot'), pgv.t('stock.col_type')], v_rows);
  END IF;

  SELECT name INTO v_warehouse_name FROM stock.warehouse WHERE id = p_warehouse_id AND active;
  IF v_warehouse_name IS NULL THEN
    RETURN pgv.empty(pgv.t('stock.empty_depot_not_found'), pgv.t('stock.empty_depot_inactive'));
  END IF;

  v_body := format('<h3>%s : %s</h3>', pgv.t('stock.nav_inventaire'), pgv.esc(v_warehouse_name));

  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT a.id, a.reference, a.description, a.unit
    FROM stock.article a WHERE a.active ORDER BY a.description
  LOOP
    v_qty := stock._current_stock(r.id, p_warehouse_id);
    v_rows := v_rows || ARRAY[
      pgv.esc(r.reference), pgv.esc(r.description), r.unit, v_qty::text,
      format('<input type="number" name="qty_%s" value="%s" step="0.01" class="pgv-input-sm">', r.id, v_qty)
    ];
  END LOOP;

  IF array_length(v_rows, 1) IS NULL THEN
    v_form_body := format('<input type="hidden" name="p_warehouse_id" value="%s">', p_warehouse_id)
      || pgv.empty(pgv.t('stock.empty_no_article'), pgv.t('stock.empty_no_article_actif'));
    v_body := v_body || pgv.form('post_inventory_validate', v_form_body, pgv.t('stock.btn_valider_inventaire'));
    RETURN v_body;
  END IF;

  v_form_body := format('<input type="hidden" name="p_warehouse_id" value="%s">', p_warehouse_id)
    || pgv.md_table(
      ARRAY[pgv.t('stock.col_ref'), pgv.t('stock.col_designation'), pgv.t('stock.col_unite'), pgv.t('stock.col_theorique'), pgv.t('stock.col_reel')],
      v_rows);

  v_body := v_body || pgv.form('post_inventory_validate', v_form_body, pgv.t('stock.btn_valider_inventaire'));

  RETURN v_body;
END;
$function$;
