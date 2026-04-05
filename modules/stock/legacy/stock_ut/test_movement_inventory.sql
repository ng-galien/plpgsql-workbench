CREATE OR REPLACE FUNCTION stock_ut.test_movement_inventory()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art_id int;
  v_wh_id int;
  v_qty numeric;
  v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  INSERT INTO stock.warehouse (name, type, tenant_id) VALUES ('Test warehouse', 'workshop', 'test') RETURNING id INTO v_wh_id;
  INSERT INTO stock.article (reference, description, category, wap, tenant_id) VALUES ('TEST-I01', 'Inventory test', 'wood', 50.0000, 'test') RETURNING id INTO v_art_id;

  INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, tenant_id)
  VALUES (v_art_id, v_wh_id, 'entry', 10, 50.00, 'test');

  v_result := stock.post_movement_save(jsonb_build_object(
    'type', 'inventory', 'article_id', v_art_id, 'warehouse_id', v_wh_id, 'quantity', '7'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'inventaire success');

  SELECT coalesce(sum(quantity), 0) INTO v_qty FROM stock.movement WHERE article_id = v_art_id AND warehouse_id = v_wh_id;
  RETURN NEXT is(v_qty, 7::numeric, 'stock after inventaire = 7');

  v_result := stock.post_movement_save(jsonb_build_object(
    'type', 'inventory', 'article_id', v_art_id, 'warehouse_id', v_wh_id, 'quantity', '7'
  ));
  RETURN NEXT ok(v_result LIKE '%correct%', 'no adjustment when correct');

  DELETE FROM stock.movement WHERE tenant_id = 'test';
  DELETE FROM stock.article WHERE tenant_id = 'test';
  DELETE FROM stock.warehouse WHERE tenant_id = 'test';
END;
$function$;
