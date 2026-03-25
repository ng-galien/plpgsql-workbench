CREATE OR REPLACE FUNCTION stock.post_inventory_validate(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_warehouse_id int := (p_data->>'p_warehouse_id')::int;
  v_key text;
  v_val text;
  v_article_id int;
  v_qty_actual numeric;
  v_qty_theoretical numeric;
  v_diff numeric;
  v_nb_adjustments int := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM stock.warehouse WHERE id = v_warehouse_id AND active) THEN
    RETURN pgv.toast(pgv.t('stock.err_depot_not_found'), 'error');
  END IF;

  FOR v_key, v_val IN SELECT key, value FROM jsonb_each_text(p_data) WHERE key LIKE 'qty_%'
  LOOP
    v_article_id := replace(v_key, 'qty_', '')::int;
    v_qty_actual := v_val::numeric;
    v_qty_theoretical := stock._current_stock(v_article_id, v_warehouse_id);
    v_diff := v_qty_actual - v_qty_theoretical;

    IF v_diff = 0 THEN
      CONTINUE;
    END IF;

    INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, reference)
    VALUES (v_article_id, v_warehouse_id, 'inventory', v_diff,
            'INV-' || to_char(now(), 'YYYYMMDD'));

    v_nb_adjustments := v_nb_adjustments + 1;
  END LOOP;

  IF v_nb_adjustments = 0 THEN
    RETURN pgv.toast(pgv.t('stock.toast_stock_conforme'))
      || pgv.redirect(pgv.call_ref('get_inventory', jsonb_build_object('p_warehouse_id', v_warehouse_id)));
  END IF;

  RETURN pgv.toast(format(pgv.t('stock.toast_inventaire_valide'), v_nb_adjustments))
    || pgv.redirect(pgv.call_ref('get_warehouse', jsonb_build_object('p_id', v_warehouse_id)));
END;
$function$;
