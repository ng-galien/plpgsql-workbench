CREATE OR REPLACE FUNCTION stock.purchase_reception(p_data jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_warehouse_id int := (p_data->>'warehouse_id')::int;
  v_ref text := coalesce(p_data->>'reception_ref', 'RECEPTION');
  v_lines jsonb := p_data->'lines';
  v_line jsonb;
  v_article_id int;
  v_quantity numeric;
  v_price numeric;
  v_nb_articles int := 0;
  v_total_qty numeric := 0;
  v_total_value numeric := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM stock.warehouse WHERE id = v_warehouse_id AND active) THEN
    RETURN jsonb_build_object('ok', false, 'error', pgv.t('stock.err_depot_inactive'));
  END IF;

  IF v_lines IS NULL OR jsonb_array_length(v_lines) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', pgv.t('stock.err_no_lignes'));
  END IF;

  FOR i IN 0 .. jsonb_array_length(v_lines) - 1 LOOP
    v_line := v_lines->i;
    v_article_id := (v_line->>'article_id')::int;
    v_quantity := (v_line->>'quantity')::numeric;
    v_price := (v_line->>'unit_price')::numeric;

    IF NOT EXISTS (SELECT 1 FROM stock.article WHERE id = v_article_id AND active) THEN
      CONTINUE;
    END IF;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      CONTINUE;
    END IF;

    INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, reference)
    VALUES (v_article_id, v_warehouse_id, 'entry', v_quantity, v_price, v_ref);

    PERFORM stock._recalc_wap(v_article_id);

    IF v_price IS NOT NULL THEN
      UPDATE stock.article SET purchase_price = v_price WHERE id = v_article_id;
    END IF;

    v_nb_articles := v_nb_articles + 1;
    v_total_qty := v_total_qty + v_quantity;
    v_total_value := v_total_value + coalesce(v_quantity * v_price, 0);
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'nb_articles', v_nb_articles,
    'total_quantity', v_total_qty,
    'total_value', round(v_total_value, 2),
    'warehouse_id', v_warehouse_id,
    'reference', v_ref
  );
END;
$function$;
