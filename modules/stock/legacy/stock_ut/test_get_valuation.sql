CREATE OR REPLACE FUNCTION stock_ut.test_get_valuation()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_supplier_id int;
  v_wh_id int;
  v_art_id int;
  v_result text;
BEGIN
  INSERT INTO crm.client (type, name) VALUES ('company', 'UT Valo Supplier')
  RETURNING id INTO v_supplier_id;

  INSERT INTO stock.warehouse (name, type) VALUES ('UT Valo Storage', 'storage')
  RETURNING id INTO v_wh_id;

  INSERT INTO stock.article (reference, description, category, unit, purchase_price, wap, supplier_id)
  VALUES ('UT-VALO-001', 'Pine battens', 'wood', 'm', 2.50, 2.50, v_supplier_id)
  RETURNING id INTO v_art_id;

  INSERT INTO stock.movement (article_id, warehouse_id, type, quantity, unit_price, reference)
  VALUES (v_art_id, v_wh_id, 'entry', 100, 2.50, 'SEED-VALO');

  v_result := stock.get_valuation();
  RETURN NEXT ok(v_result IS NOT NULL, 'get_valorisation returns content');
  RETURN NEXT ok(v_result LIKE '%Valeur totale%', 'contains valeur totale stat');
  RETURN NEXT ok(v_result LIKE '%Par dépôt%', 'contains depot section');
  RETURN NEXT ok(v_result LIKE '%UT Valo Storage%', 'contains depot name');
  RETURN NEXT ok(v_result LIKE '%Par catégorie%', 'contains category section');
  RETURN NEXT ok(v_result LIKE '%wood%', 'contains bois category');

  DELETE FROM stock.movement WHERE article_id = v_art_id;
  DELETE FROM stock.article WHERE id = v_art_id;
  DELETE FROM stock.warehouse WHERE id = v_wh_id;
  DELETE FROM crm.client WHERE id = v_supplier_id;
END;
$function$;
