CREATE OR REPLACE FUNCTION stock_ut.test_movement_transfer()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art_id int;
  v_wh_a int;
  v_wh_b int;
  v_qty_a numeric;
  v_qty_b numeric;
  v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  INSERT INTO stock.warehouse (name, type, tenant_id) VALUES ('Warehouse A', 'workshop', 'test') RETURNING id INTO v_wh_a;
  INSERT INTO stock.warehouse (name, type, tenant_id) VALUES ('Warehouse B', 'vehicle', 'test') RETURNING id INTO v_wh_b;
  INSERT INTO stock.article (reference, description, category, wap, tenant_id) VALUES ('TEST-T01', 'Transfer test', 'wood', 50.0000, 'test') RETURNING id INTO v_art_id;

  INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, tenant_id)
  VALUES (v_art_id, v_wh_a, 'entry', 20, 50.00, 'test');

  v_result := stock.post_movement_save(jsonb_build_object(
    'type', 'transfer', 'article_id', v_art_id, 'warehouse_id', v_wh_a,
    'destination_warehouse_id', v_wh_b, 'quantity', '8'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'transfert success');

  SELECT coalesce(sum(quantity), 0) INTO v_qty_a FROM stock.movement WHERE article_id = v_art_id AND warehouse_id = v_wh_a;
  SELECT coalesce(sum(quantity), 0) INTO v_qty_b FROM stock.movement WHERE article_id = v_art_id AND warehouse_id = v_wh_b;
  RETURN NEXT is(v_qty_a, 12::numeric, 'depot A stock = 12');
  RETURN NEXT is(v_qty_b, 8::numeric, 'depot B stock = 8');

  v_result := stock.post_movement_save(jsonb_build_object(
    'type', 'transfer', 'article_id', v_art_id, 'warehouse_id', v_wh_a,
    'destination_warehouse_id', v_wh_a, 'quantity', '5'
  ));
  RETURN NEXT ok(v_result LIKE '%identiques%', 'same depot blocked');

  DELETE FROM stock.movement WHERE tenant_id = 'test';
  DELETE FROM stock.article WHERE tenant_id = 'test';
  DELETE FROM stock.warehouse WHERE tenant_id = 'test';
END;
$function$;
