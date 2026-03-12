CREATE OR REPLACE FUNCTION purchase_ut.test_totaux()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_fournisseur_id int;
  v_ht numeric;
  v_ttc numeric;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  INSERT INTO crm.client (type, name, tags)
  VALUES ('company', '_test_totaux_', ARRAY['fournisseur'])
  RETURNING id INTO v_fournisseur_id;

  INSERT INTO purchase.commande (numero, fournisseur_id, objet)
  VALUES ('CMD-TEST-TOT', v_fournisseur_id, 'Test totaux')
  RETURNING id INTO v_id;

  -- 2 x 100.00 @ 20% TVA = 200 HT, 40 TVA, 240 TTC
  INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, prix_unitaire, tva_rate)
  VALUES (v_id, 1, 'Article A', 2, 100.00, 20.00);

  -- 1 x 50.00 @ 10% TVA = 50 HT, 5 TVA, 55 TTC
  INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, prix_unitaire, tva_rate)
  VALUES (v_id, 2, 'Article B', 1, 50.00, 10.00);

  -- Test via get_commande (which uses _total_* internally)
  SELECT sum(quantite * prix_unitaire) INTO v_ht FROM purchase.ligne WHERE commande_id = v_id;
  RETURN NEXT is(v_ht, 250.00::numeric, 'total HT = 250');

  SELECT sum(quantite * prix_unitaire * (1 + tva_rate/100)) INTO v_ttc FROM purchase.ligne WHERE commande_id = v_id;
  RETURN NEXT is(v_ttc, 295.00::numeric, 'total TTC = 295');

  -- Verify page renders with totals
  RETURN NEXT ok(purchase.get_commande(v_id) LIKE '%295%', 'detail page shows TTC total');

  -- Cleanup
  DELETE FROM purchase.ligne WHERE commande_id = v_id;
  DELETE FROM purchase.commande WHERE id = v_id;
  DELETE FROM crm.client WHERE id = v_fournisseur_id;
END;
$function$;
