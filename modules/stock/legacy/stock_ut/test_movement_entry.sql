CREATE OR REPLACE FUNCTION stock_ut.test_movement_entry()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_art_id int;
  v_wh_id int;
  v_qty numeric;
  v_wap numeric;
  v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  INSERT INTO stock.warehouse (name, type, tenant_id) VALUES ('Test warehouse', 'workshop', 'test') RETURNING id INTO v_wh_id;
  INSERT INTO stock.article (reference, description, category, tenant_id) VALUES ('TEST-E01', 'Entry test', 'wood', 'test') RETURNING id INTO v_art_id;

  v_result := stock.post_movement_save(jsonb_build_object(
    'type', 'entry', 'article_id', v_art_id, 'warehouse_id', v_wh_id,
    'quantity', '10', 'unit_price', '50'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'entry success toast');

  SELECT coalesce(sum(quantity), 0) INTO v_qty FROM stock.movement WHERE article_id = v_art_id AND warehouse_id = v_wh_id;
  RETURN NEXT is(v_qty, 10::numeric, 'stock after entry = 10');

  SELECT wap INTO v_wap FROM stock.article WHERE id = v_art_id;
  RETURN NEXT is(v_wap, 50.0000::numeric(12,4), 'PMP = 50 after first entry');

  v_result := stock.post_movement_save(jsonb_build_object(
    'type', 'entry', 'article_id', v_art_id, 'warehouse_id', v_wh_id,
    'quantity', '10', 'unit_price', '70'
  ));

  SELECT wap INTO v_wap FROM stock.article WHERE id = v_art_id;
  RETURN NEXT is(v_wap, 60.0000::numeric(12,4), 'PMP = 60 after weighted avg');

  SELECT coalesce(sum(quantity), 0) INTO v_qty FROM stock.movement WHERE article_id = v_art_id;
  RETURN NEXT is(v_qty, 20::numeric, 'total stock = 20');

  DELETE FROM stock.movement WHERE tenant_id = 'test';
  DELETE FROM stock.article WHERE tenant_id = 'test';
  DELETE FROM stock.warehouse WHERE tenant_id = 'test';
END;
$function$;
