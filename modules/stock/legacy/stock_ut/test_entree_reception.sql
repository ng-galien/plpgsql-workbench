CREATE OR REPLACE FUNCTION stock_ut.test_entree_reception()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_fournisseur_id int;
  v_depot_id int;
  v_art1_id int;
  v_art2_id int;
  v_result jsonb;
  v_stock numeric;
  v_pmp numeric;
BEGIN
  -- Setup: fournisseur, depot, 2 articles
  INSERT INTO crm.client (type, name) VALUES ('company', 'UT Fournisseur Reception')
  RETURNING id INTO v_fournisseur_id;

  INSERT INTO stock.depot (nom, type) VALUES ('UT Depot Reception', 'entrepot')
  RETURNING id INTO v_depot_id;

  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, fournisseur_id)
  VALUES ('UT-REC-001', 'Chevron 60x80', 'bois', 'm', 3.50, v_fournisseur_id)
  RETURNING id INTO v_art1_id;

  INSERT INTO stock.article (reference, designation, categorie, unite, prix_achat, fournisseur_id)
  VALUES ('UT-REC-002', 'Vis 6x80', 'quincaillerie', 'u', 0.05, v_fournisseur_id)
  RETURNING id INTO v_art2_id;

  -- Test 1: reception avec 2 articles
  v_result := stock.entree_reception(jsonb_build_object(
    'reception_ref', 'REC-UT-001',
    'depot_id', v_depot_id,
    'lignes', jsonb_build_array(
      jsonb_build_object('article_id', v_art1_id, 'quantite', 20, 'prix_unitaire', 3.80),
      jsonb_build_object('article_id', v_art2_id, 'quantite', 500, 'prix_unitaire', 0.04)
    )
  ));
  RETURN NEXT ok((v_result->>'ok')::boolean, 'reception returns ok=true');
  RETURN NEXT is((v_result->>'nb_articles')::int, 2, '2 articles received');
  RETURN NEXT is((v_result->>'total_quantite')::numeric, 520::numeric, 'total qty = 520');

  -- Verify stock levels
  SELECT sum(quantite) INTO v_stock FROM stock.mouvement WHERE article_id = v_art1_id;
  RETURN NEXT is(v_stock, 20::numeric, 'art1 stock = 20');

  SELECT sum(quantite) INTO v_stock FROM stock.mouvement WHERE article_id = v_art2_id;
  RETURN NEXT is(v_stock, 500::numeric, 'art2 stock = 500');

  -- Verify PMP updated
  SELECT pmp INTO v_pmp FROM stock.article WHERE id = v_art1_id;
  RETURN NEXT is(v_pmp, 3.8000::numeric, 'art1 PMP = 3.80');

  -- Verify prix_achat updated
  SELECT prix_achat INTO v_pmp FROM stock.article WHERE id = v_art1_id;
  RETURN NEXT is(v_pmp, 3.80::numeric, 'art1 prix_achat updated');

  -- Test 2: depot invalide
  v_result := stock.entree_reception('{"depot_id": 99999, "lignes": []}'::jsonb);
  RETURN NEXT ok(NOT (v_result->>'ok')::boolean, 'invalid depot returns ok=false');

  -- Test 3: lignes vides
  v_result := stock.entree_reception(jsonb_build_object('depot_id', v_depot_id, 'lignes', '[]'::jsonb));
  RETURN NEXT ok(NOT (v_result->>'ok')::boolean, 'empty lignes returns ok=false');

  -- Test 4: article inexistant skipped
  v_result := stock.entree_reception(jsonb_build_object(
    'depot_id', v_depot_id,
    'reception_ref', 'REC-UT-002',
    'lignes', jsonb_build_array(
      jsonb_build_object('article_id', 99999, 'quantite', 10, 'prix_unitaire', 1.00),
      jsonb_build_object('article_id', v_art1_id, 'quantite', 5, 'prix_unitaire', 4.00)
    )
  ));
  RETURN NEXT is((v_result->>'nb_articles')::int, 1, 'unknown article skipped');

  -- Verify cumulative stock on art1 (20 + 5 = 25)
  SELECT sum(quantite) INTO v_stock FROM stock.mouvement WHERE article_id = v_art1_id;
  RETURN NEXT is(v_stock, 25::numeric, 'art1 cumulative stock = 25');

  -- Verify PMP recalculated (20*3.80 + 5*4.00) / 25 = 3.84
  SELECT pmp INTO v_pmp FROM stock.article WHERE id = v_art1_id;
  RETURN NEXT is(v_pmp, 3.8400::numeric, 'art1 PMP recalculated after 2nd reception');

  -- Cleanup
  DELETE FROM stock.mouvement WHERE article_id IN (v_art1_id, v_art2_id);
  DELETE FROM stock.article WHERE id IN (v_art1_id, v_art2_id);
  DELETE FROM stock.depot WHERE id = v_depot_id;
  DELETE FROM crm.client WHERE id = v_fournisseur_id;
END;
$function$;
