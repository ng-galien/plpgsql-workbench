CREATE OR REPLACE FUNCTION purchase_ut.test_commande_workflow()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_result text;
  v_fournisseur_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Setup: create a supplier
  INSERT INTO crm.client (type, name, tags)
  VALUES ('company', '_test_fournisseur_', ARRAY['fournisseur'])
  RETURNING id INTO v_fournisseur_id;

  -- Create order
  v_result := purchase.post_commande_save(jsonb_build_object(
    'p_fournisseur_id', v_fournisseur_id,
    'p_objet', 'Test commande workflow'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create order returns success');

  SELECT id INTO v_id FROM purchase.commande WHERE objet = 'Test commande workflow';
  RETURN NEXT ok(v_id IS NOT NULL, 'order created');

  -- Add lines
  v_result := purchase.post_ligne_ajouter(jsonb_build_object(
    'p_commande_id', v_id,
    'p_description', 'Test article',
    'p_quantite', 5,
    'p_prix_unitaire', 10.00
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'add line returns success');

  -- Send
  v_result := purchase.post_commande_envoyer(jsonb_build_object('p_id', v_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'send returns success');
  RETURN NEXT is((SELECT statut FROM purchase.commande WHERE id = v_id), 'envoyee', 'status is envoyee');

  -- Receive
  v_result := purchase.post_reception_creer(jsonb_build_object('p_commande_id', v_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'reception returns success');
  RETURN NEXT is((SELECT statut FROM purchase.commande WHERE id = v_id), 'recue', 'status is recue after full reception');

  -- Cleanup
  DELETE FROM purchase.reception_ligne WHERE reception_id IN (SELECT id FROM purchase.reception WHERE commande_id = v_id);
  DELETE FROM purchase.reception WHERE commande_id = v_id;
  DELETE FROM purchase.ligne WHERE commande_id = v_id;
  DELETE FROM purchase.commande WHERE id = v_id;
  DELETE FROM crm.client WHERE id = v_fournisseur_id;
END;
$function$;
