CREATE OR REPLACE FUNCTION stock_ut.test_post_inventory_validate()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_supplier_id int;
  v_wh_id int;
  v_art1_id int;
  v_art2_id int;
  v_result text;
  v_stock numeric;
BEGIN
  INSERT INTO crm.client (type, name) VALUES ('company', 'UT Inv Supplier')
  RETURNING id INTO v_supplier_id;

  INSERT INTO stock.warehouse (name, type) VALUES ('UT Inv Warehouse', 'storage')
  RETURNING id INTO v_wh_id;

  INSERT INTO stock.article (reference, description, category, unit, supplier_id)
  VALUES ('UT-INV-001', 'Oak plank', 'wood', 'm', v_supplier_id)
  RETURNING id INTO v_art1_id;

  INSERT INTO stock.article (reference, description, category, unit, supplier_id)
  VALUES ('UT-INV-002', 'PU glue', 'finish', 'l', v_supplier_id)
  RETURNING id INTO v_art2_id;

  INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, reference)
  VALUES (v_art1_id, v_wh_id, 'entry', 10, 8.00, 'SEED'),
         (v_art2_id, v_wh_id, 'entry', 5, 12.00, 'SEED');

  v_result := stock.post_inventory_validate(jsonb_build_object(
    'p_warehouse_id', v_wh_id,
    'qty_' || v_art1_id, '7',
    'qty_' || v_art2_id, '5'
  ));
  RETURN NEXT ok(v_result LIKE '%Inventaire validé%', 'inventaire success toast');
  RETURN NEXT ok(v_result LIKE '%1 ajustement%', '1 adjustment (art2 unchanged)');

  SELECT sum(quantity) INTO v_stock FROM stock.movement WHERE article_id = v_art1_id AND warehouse_id = v_wh_id;
  RETURN NEXT is(v_stock, 7::numeric, 'art1 stock adjusted to 7');

  SELECT sum(quantity) INTO v_stock FROM stock.movement WHERE article_id = v_art2_id AND warehouse_id = v_wh_id;
  RETURN NEXT is(v_stock, 5::numeric, 'art2 stock unchanged');

  v_result := stock.post_inventory_validate(jsonb_build_object(
    'p_warehouse_id', v_wh_id,
    'qty_' || v_art1_id, '7',
    'qty_' || v_art2_id, '5'
  ));
  RETURN NEXT ok(v_result LIKE '%Stock conforme%', 'no adjustment needed');

  v_result := stock.post_inventory_validate(jsonb_build_object(
    'p_warehouse_id', v_wh_id,
    'qty_' || v_art2_id, '8'
  ));
  SELECT sum(quantity) INTO v_stock FROM stock.movement WHERE article_id = v_art2_id AND warehouse_id = v_wh_id;
  RETURN NEXT is(v_stock, 8::numeric, 'art2 stock increased to 8');

  v_result := stock.post_inventory_validate('{"p_warehouse_id": 99999}'::jsonb);
  RETURN NEXT ok(v_result LIKE '%introuvable%', 'invalid depot blocked');

  DELETE FROM stock.movement WHERE article_id IN (v_art1_id, v_art2_id);
  DELETE FROM stock.article WHERE id IN (v_art1_id, v_art2_id);
  DELETE FROM stock.warehouse WHERE id = v_wh_id;
  DELETE FROM crm.client WHERE id = v_supplier_id;
END;
$function$;
