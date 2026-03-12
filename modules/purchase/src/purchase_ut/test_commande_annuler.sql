CREATE OR REPLACE FUNCTION purchase_ut.test_commande_annuler()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_result text;
  v_fournisseur_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  INSERT INTO crm.client (type, name, tags)
  VALUES ('company', '_test_annuler_', ARRAY['fournisseur'])
  RETURNING id INTO v_fournisseur_id;

  -- Create + add line
  v_result := purchase.post_commande_save(jsonb_build_object(
    'p_fournisseur_id', v_fournisseur_id,
    'p_objet', 'Test annulation'
  ));
  SELECT id INTO v_id FROM purchase.commande WHERE objet = 'Test annulation';

  v_result := purchase.post_ligne_ajouter(jsonb_build_object(
    'p_commande_id', v_id,
    'p_description', 'Ligne test',
    'p_prix_unitaire', 10.00
  ));

  -- Cancel from brouillon
  v_result := purchase.post_commande_annuler(jsonb_build_object('p_id', v_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'cancel brouillon succeeds');
  RETURN NEXT is((SELECT statut FROM purchase.commande WHERE id = v_id), 'annulee', 'status is annulee');

  -- Cannot cancel again
  v_result := purchase.post_commande_annuler(jsonb_build_object('p_id', v_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'cannot cancel already cancelled');

  -- Test cancel from envoyee
  UPDATE purchase.commande SET statut = 'brouillon' WHERE id = v_id;
  v_result := purchase.post_commande_envoyer(jsonb_build_object('p_id', v_id));
  v_result := purchase.post_commande_annuler(jsonb_build_object('p_id', v_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'cancel envoyee succeeds');

  -- Test cannot cancel with receptions
  UPDATE purchase.commande SET statut = 'envoyee' WHERE id = v_id;
  INSERT INTO purchase.reception (commande_id, numero) VALUES (v_id, 'REC-TEST-ANN');
  v_result := purchase.post_commande_annuler(jsonb_build_object('p_id', v_id));
  RETURN NEXT ok(v_result LIKE '%des réceptions existent%', 'cannot cancel with receptions');

  -- Cleanup
  DELETE FROM purchase.reception WHERE commande_id = v_id;
  DELETE FROM purchase.ligne WHERE commande_id = v_id;
  DELETE FROM purchase.commande WHERE id = v_id;
  DELETE FROM crm.client WHERE id = v_fournisseur_id;
END;
$function$;
