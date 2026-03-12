CREATE OR REPLACE FUNCTION purchase_ut.test_facture_workflow()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cmd_id int;
  v_fac_id int;
  v_result text;
  v_fournisseur_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  INSERT INTO crm.client (type, name, tags)
  VALUES ('company', '_test_facture_', ARRAY['fournisseur'])
  RETURNING id INTO v_fournisseur_id;

  -- Create a received order
  INSERT INTO purchase.commande (numero, fournisseur_id, objet, statut)
  VALUES ('CMD-TEST-FAC', v_fournisseur_id, 'Test facture', 'recue')
  RETURNING id INTO v_cmd_id;

  INSERT INTO purchase.ligne (commande_id, sort_order, description, quantite, prix_unitaire, tva_rate)
  VALUES (v_cmd_id, 1, 'Article test', 2, 100.00, 20.00);

  -- Saisir facture
  v_result := purchase.post_facture_saisir(jsonb_build_object(
    'p_commande_id', v_cmd_id,
    'p_numero_fournisseur', 'FAC-TEST-001',
    'p_montant_ht', 200.00,
    'p_montant_ttc', 240.00,
    'p_date_facture', now()::date::text
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'saisir facture succeeds');

  SELECT id INTO v_fac_id FROM purchase.facture_fournisseur WHERE numero_fournisseur = 'FAC-TEST-001';
  RETURN NEXT ok(v_fac_id IS NOT NULL, 'facture created');
  RETURN NEXT is((SELECT statut FROM purchase.facture_fournisseur WHERE id = v_fac_id), 'recue', 'initial status is recue');

  -- Valider
  v_result := purchase.post_facture_valider(jsonb_build_object('p_id', v_fac_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'valider succeeds');
  RETURN NEXT is((SELECT statut FROM purchase.facture_fournisseur WHERE id = v_fac_id), 'validee', 'status is validee');

  -- Cannot validate again
  v_result := purchase.post_facture_valider(jsonb_build_object('p_id', v_fac_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'cannot validate twice');

  -- Payer
  v_result := purchase.post_facture_payer(jsonb_build_object('p_id', v_fac_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'payer succeeds');
  RETURN NEXT is((SELECT statut FROM purchase.facture_fournisseur WHERE id = v_fac_id), 'payee', 'status is payee');

  -- Cannot pay again
  v_result := purchase.post_facture_payer(jsonb_build_object('p_id', v_fac_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'cannot pay twice');

  -- Cleanup
  DELETE FROM purchase.facture_fournisseur WHERE id = v_fac_id;
  DELETE FROM purchase.ligne WHERE commande_id = v_cmd_id;
  DELETE FROM purchase.commande WHERE id = v_cmd_id;
  DELETE FROM crm.client WHERE id = v_fournisseur_id;
END;
$function$;
