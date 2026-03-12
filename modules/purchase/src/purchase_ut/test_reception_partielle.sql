CREATE OR REPLACE FUNCTION purchase_ut.test_reception_partielle()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cmd_id int;
  v_fournisseur_id int;
  v_result text;
  v_remaining numeric;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  INSERT INTO crm.client (type, name, tags)
  VALUES ('company', '_test_partial_', ARRAY['fournisseur'])
  RETURNING id INTO v_fournisseur_id;

  -- Create and send order with 10 items
  v_result := purchase.post_commande_save(jsonb_build_object(
    'p_fournisseur_id', v_fournisseur_id,
    'p_objet', 'Test reception partielle'
  ));
  SELECT id INTO v_cmd_id FROM purchase.commande WHERE objet = 'Test reception partielle';

  v_result := purchase.post_ligne_ajouter(jsonb_build_object(
    'p_commande_id', v_cmd_id,
    'p_description', 'Planches test',
    'p_quantite', 10,
    'p_prix_unitaire', 25.00
  ));

  v_result := purchase.post_commande_envoyer(jsonb_build_object('p_id', v_cmd_id));
  RETURN NEXT is((SELECT statut FROM purchase.commande WHERE id = v_cmd_id), 'envoyee', 'order is envoyee');

  -- Full reception via post_reception_creer (receives all remaining)
  v_result := purchase.post_reception_creer(jsonb_build_object('p_commande_id', v_cmd_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'reception created');
  RETURN NEXT is((SELECT statut FROM purchase.commande WHERE id = v_cmd_id), 'recue', 'status becomes recue');

  -- Check remaining via SQL
  SELECT l.quantite - coalesce(sum(rl.quantite_recue), 0) INTO v_remaining
    FROM purchase.ligne l
    LEFT JOIN purchase.reception_ligne rl ON rl.ligne_id = l.id
   WHERE l.commande_id = v_cmd_id
   GROUP BY l.id;

  RETURN NEXT is(v_remaining, 0.00::numeric, 'no remaining quantity');

  -- Second reception should fail (nothing left)
  v_result := purchase.post_reception_creer(jsonb_build_object('p_commande_id', v_cmd_id));
  RETURN NEXT ok(v_result LIKE '%Commande non réceptionnable%', 'cannot receive already received');

  -- Cleanup
  DELETE FROM purchase.reception_ligne WHERE reception_id IN (SELECT id FROM purchase.reception WHERE commande_id = v_cmd_id);
  DELETE FROM purchase.reception WHERE commande_id = v_cmd_id;
  DELETE FROM purchase.ligne WHERE commande_id = v_cmd_id;
  DELETE FROM purchase.commande WHERE id = v_cmd_id;
  DELETE FROM crm.client WHERE id = v_fournisseur_id;
END;
$function$;
