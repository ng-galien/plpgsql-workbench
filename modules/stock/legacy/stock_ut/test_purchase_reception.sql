CREATE OR REPLACE FUNCTION stock_ut.test_purchase_reception()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_supplier_id int;
  v_wh_id int;
  v_art1_id int;
  v_art2_id int;
  v_result jsonb;
  v_stock numeric;
  v_wap numeric;
BEGIN
  INSERT INTO crm.client (type, name) VALUES ('company', 'UT Supplier Reception')
  RETURNING id INTO v_supplier_id;

  INSERT INTO stock.warehouse (name, type) VALUES ('UT Warehouse Reception', 'storage')
  RETURNING id INTO v_wh_id;

  INSERT INTO stock.article (reference, description, category, unit, purchase_price, supplier_id)
  VALUES ('UT-REC-001', 'Chevron 60x80', 'wood', 'm', 3.50, v_supplier_id)
  RETURNING id INTO v_art1_id;

  INSERT INTO stock.article (reference, description, category, unit, purchase_price, supplier_id)
  VALUES ('UT-REC-002', 'Vis 6x80', 'hardware', 'ea', 0.05, v_supplier_id)
  RETURNING id INTO v_art2_id;

  v_result := stock.purchase_reception(jsonb_build_object(
    'reception_ref', 'REC-UT-001',
    'warehouse_id', v_wh_id,
    'lines', jsonb_build_array(
      jsonb_build_object('article_id', v_art1_id, 'quantity', 20, 'unit_price', 3.80),
      jsonb_build_object('article_id', v_art2_id, 'quantity', 500, 'unit_price', 0.04)
    )
  ));
  RETURN NEXT ok((v_result->>'ok')::boolean, 'reception returns ok=true');
  RETURN NEXT is((v_result->>'nb_articles')::int, 2, '2 articles received');
  RETURN NEXT is((v_result->>'total_quantity')::numeric, 520::numeric, 'total qty = 520');

  SELECT sum(quantity) INTO v_stock FROM stock.movement WHERE article_id = v_art1_id;
  RETURN NEXT is(v_stock, 20::numeric, 'art1 stock = 20');

  SELECT sum(quantity) INTO v_stock FROM stock.movement WHERE article_id = v_art2_id;
  RETURN NEXT is(v_stock, 500::numeric, 'art2 stock = 500');

  SELECT wap INTO v_wap FROM stock.article WHERE id = v_art1_id;
  RETURN NEXT is(v_wap, 3.8000::numeric, 'art1 PMP = 3.80');

  SELECT purchase_price INTO v_wap FROM stock.article WHERE id = v_art1_id;
  RETURN NEXT is(v_wap, 3.80::numeric, 'art1 prix_achat updated');

  v_result := stock.purchase_reception('{"warehouse_id": 99999, "lines": []}'::jsonb);
  RETURN NEXT ok(NOT (v_result->>'ok')::boolean, 'invalid depot returns ok=false');

  v_result := stock.purchase_reception(jsonb_build_object('warehouse_id', v_wh_id, 'lines', '[]'::jsonb));
  RETURN NEXT ok(NOT (v_result->>'ok')::boolean, 'empty lignes returns ok=false');

  v_result := stock.purchase_reception(jsonb_build_object(
    'warehouse_id', v_wh_id, 'reception_ref', 'REC-UT-002',
    'lines', jsonb_build_array(
      jsonb_build_object('article_id', 99999, 'quantity', 10, 'unit_price', 1.00),
      jsonb_build_object('article_id', v_art1_id, 'quantity', 5, 'unit_price', 4.00)
    )
  ));
  RETURN NEXT is((v_result->>'nb_articles')::int, 1, 'unknown article skipped');

  SELECT sum(quantity) INTO v_stock FROM stock.movement WHERE article_id = v_art1_id;
  RETURN NEXT is(v_stock, 25::numeric, 'art1 cumulative stock = 25');

  SELECT wap INTO v_wap FROM stock.article WHERE id = v_art1_id;
  RETURN NEXT is(v_wap, 3.8400::numeric, 'art1 PMP recalculated after 2nd reception');

  DELETE FROM stock.movement WHERE article_id IN (v_art1_id, v_art2_id);
  DELETE FROM stock.article WHERE id IN (v_art1_id, v_art2_id);
  DELETE FROM stock.warehouse WHERE id = v_wh_id;
  DELETE FROM crm.client WHERE id = v_supplier_id;
END;
$function$;
