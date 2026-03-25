CREATE OR REPLACE FUNCTION stock.post_movement_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_type text;
  v_article_id int;
  v_warehouse_id int;
  v_dest_id int;
  v_qty numeric;
  v_up numeric;
  v_art stock.article;
BEGIN
  v_type := p_data->>'type';
  v_article_id := (p_data->>'article_id')::int;
  v_warehouse_id := (p_data->>'warehouse_id')::int;
  v_dest_id := nullif(p_data->>'destination_warehouse_id', '')::int;
  v_qty := (p_data->>'quantity')::numeric;
  v_up := nullif(p_data->>'unit_price', '')::numeric;

  SELECT * INTO v_art FROM stock.article WHERE id = v_article_id;
  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('stock.err_article_not_found'), 'error');
  END IF;

  IF v_type = 'transfer' AND v_dest_id IS NULL THEN
    RETURN pgv.toast(pgv.t('stock.err_depot_dest_requis'), 'error');
  END IF;
  IF v_type = 'transfer' AND v_warehouse_id = v_dest_id THEN
    RETURN pgv.toast(pgv.t('stock.err_depot_src_dest_identiques'), 'error');
  END IF;

  IF v_type = 'exit' THEN
    IF stock._current_stock(v_article_id, v_warehouse_id) < v_qty THEN
      RETURN pgv.toast(pgv.t('stock.err_stock_insuffisant'), 'error');
    END IF;
  END IF;

  IF v_type = 'entry' THEN
    INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, reference, notes)
    VALUES (v_article_id, v_warehouse_id, 'entry', v_qty, coalesce(v_up, v_art.purchase_price), nullif(p_data->>'reference', ''), coalesce(p_data->>'notes', ''));

    PERFORM stock._recalc_wap(v_article_id);
    IF v_up IS NOT NULL THEN
      UPDATE stock.article SET purchase_price = v_up WHERE id = v_article_id;
    END IF;

  ELSIF v_type = 'exit' THEN
    INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, reference, notes)
    VALUES (v_article_id, v_warehouse_id, 'exit', -v_qty, v_art.wap, nullif(p_data->>'reference', ''), coalesce(p_data->>'notes', ''));

  ELSIF v_type = 'transfer' THEN
    IF stock._current_stock(v_article_id, v_warehouse_id) < v_qty THEN
      RETURN pgv.toast(pgv.t('stock.err_stock_insuffisant_transfert'), 'error');
    END IF;

    INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, reference, destination_warehouse_id, notes)
    VALUES (v_article_id, v_warehouse_id, 'transfer', -v_qty, v_art.wap, nullif(p_data->>'reference', ''), v_dest_id, coalesce(p_data->>'notes', ''));

    INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, reference, destination_warehouse_id, notes)
    VALUES (v_article_id, v_dest_id, 'transfer', v_qty, v_art.wap, nullif(p_data->>'reference', ''), v_warehouse_id, coalesce(p_data->>'notes', ''));

  ELSIF v_type = 'inventory' THEN
    DECLARE
      v_current numeric;
      v_diff numeric;
    BEGIN
      v_current := stock._current_stock(v_article_id, v_warehouse_id);
      v_diff := v_qty - v_current;

      IF v_diff = 0 THEN
        RETURN pgv.toast(pgv.t('stock.toast_stock_correct'));
      END IF;

      INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, reference, notes)
      VALUES (v_article_id, v_warehouse_id, 'inventory', v_diff, v_art.wap,
              'INV-' || to_char(now(), 'YYYYMMDD'),
              format('Inventory: %s -> %s (diff: %s)', v_current, v_qty, v_diff));
    END;
  END IF;

  RETURN pgv.toast(pgv.t('stock.toast_mvt_enregistre'))
    || pgv.redirect(pgv.call_ref('get_movements'));
END;
$function$;
