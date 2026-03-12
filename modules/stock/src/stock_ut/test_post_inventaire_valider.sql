CREATE OR REPLACE FUNCTION stock_ut.test_post_inventaire_valider()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_fournisseur_id int;
  v_depot_id int;
  v_art1_id int;
  v_art2_id int;
  v_result text;
  v_stock numeric;
BEGIN
  -- Setup
  INSERT INTO crm.client (type, name) VALUES ('company', 'UT Inv Fournisseur')
  RETURNING id INTO v_fournisseur_id;

  INSERT INTO stock.depot (nom, type) VALUES ('UT Inv Depot', 'entrepot')
  RETURNING id INTO v_depot_id;

  INSERT INTO stock.article (reference, designation, categorie, unite, fournisseur_id)
  VALUES ('UT-INV-001', 'Planche chêne', 'bois', 'm', v_fournisseur_id)
  RETURNING id INTO v_art1_id;

  INSERT INTO stock.article (reference, designation, categorie, unite, fournisseur_id)
  VALUES ('UT-INV-002', 'Colle PU', 'finition', 'l', v_fournisseur_id)
  RETURNING id INTO v_art2_id;

  -- Seed stock: art1=10, art2=5
  INSERT INTO stock.mouvement (article_id, depot_id, type, quantite, prix_unitaire, reference)
  VALUES (v_art1_id, v_depot_id, 'entree', 10, 8.00, 'SEED'),
         (v_art2_id, v_depot_id, 'entree', 5, 12.00, 'SEED');

  -- Test 1: inventaire avec écarts (art1: 10->7, art2: 5->5 no change)
  v_result := stock.post_inventaire_valider(jsonb_build_object(
    'p_depot_id', v_depot_id,
    'qty_' || v_art1_id, '7',
    'qty_' || v_art2_id, '5'
  ));
  RETURN NEXT ok(v_result LIKE '%Inventaire validé%', 'inventaire success toast');
  RETURN NEXT ok(v_result LIKE '%1 ajustement%', '1 adjustment (art2 unchanged)');

  SELECT sum(quantite) INTO v_stock FROM stock.mouvement WHERE article_id = v_art1_id AND depot_id = v_depot_id;
  RETURN NEXT is(v_stock, 7::numeric, 'art1 stock adjusted to 7');

  SELECT sum(quantite) INTO v_stock FROM stock.mouvement WHERE article_id = v_art2_id AND depot_id = v_depot_id;
  RETURN NEXT is(v_stock, 5::numeric, 'art2 stock unchanged');

  -- Test 2: inventaire sans écart
  v_result := stock.post_inventaire_valider(jsonb_build_object(
    'p_depot_id', v_depot_id,
    'qty_' || v_art1_id, '7',
    'qty_' || v_art2_id, '5'
  ));
  RETURN NEXT ok(v_result LIKE '%Stock conforme%', 'no adjustment needed');

  -- Test 3: inventaire avec augmentation
  v_result := stock.post_inventaire_valider(jsonb_build_object(
    'p_depot_id', v_depot_id,
    'qty_' || v_art2_id, '8'
  ));
  SELECT sum(quantite) INTO v_stock FROM stock.mouvement WHERE article_id = v_art2_id AND depot_id = v_depot_id;
  RETURN NEXT is(v_stock, 8::numeric, 'art2 stock increased to 8');

  -- Test 4: dépôt invalide
  v_result := stock.post_inventaire_valider('{"p_depot_id": 99999}'::jsonb);
  RETURN NEXT ok(v_result LIKE '%Dépôt introuvable%', 'invalid depot blocked');

  -- Cleanup
  DELETE FROM stock.mouvement WHERE article_id IN (v_art1_id, v_art2_id);
  DELETE FROM stock.article WHERE id IN (v_art1_id, v_art2_id);
  DELETE FROM stock.depot WHERE id = v_depot_id;
  DELETE FROM crm.client WHERE id = v_fournisseur_id;
END;
$function$;
