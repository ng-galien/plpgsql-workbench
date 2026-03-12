CREATE OR REPLACE FUNCTION purchase_ut.test_reception_partielle()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cmd_id int;
  v_fournisseur_id int;
  v_result text;
  v_remaining numeric;
  v_rec_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  INSERT INTO crm.client (type, name, tags)
  VALUES ('company', '_test_partial_', ARRAY['fournisseur'])
  RETURNING id INTO v_fournisseur_id;

  -- Create and send order with 2 lines
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

  v_result := purchase.post_ligne_ajouter(jsonb_build_object(
    'p_commande_id', v_cmd_id,
    'p_description', 'Vis test',
    'p_quantite', 5,
    'p_prix_unitaire', 2.00
  ));

  v_result := purchase.post_commande_envoyer(jsonb_build_object('p_id', v_cmd_id));
  RETURN NEXT is((SELECT statut FROM purchase.commande WHERE id = v_cmd_id), 'envoyee', 'order is envoyee');

  -- Partial reception: manually receive only first line
  INSERT INTO purchase.reception (commande_id, numero) VALUES (v_cmd_id, 'REC-TEST-P1')
  RETURNING id INTO v_rec_id;
  INSERT INTO purchase.reception_ligne (reception_id, ligne_id, quantite_recue)
  VALUES (v_rec_id, (SELECT id FROM purchase.ligne WHERE commande_id = v_cmd_id AND description = 'Planches test'), 10);
  UPDATE purchase.commande SET statut = 'partiellement_recue' WHERE id = v_cmd_id;

  -- Second reception via post_reception_creer (receives remaining line 2)
  v_result := purchase.post_reception_creer(jsonb_build_object('p_commande_id', v_cmd_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'reception created');
  RETURN NEXT is((SELECT statut FROM purchase.commande WHERE id = v_cmd_id), 'recue', 'status becomes recue');

  -- Check remaining = 0
  SELECT coalesce(sum(l.quantite - coalesce(received.total, 0)), 0) INTO v_remaining
    FROM purchase.ligne l
    LEFT JOIN (SELECT ligne_id, sum(quantite_recue) AS total FROM purchase.reception_ligne GROUP BY ligne_id) received
      ON received.ligne_id = l.id
   WHERE l.commande_id = v_cmd_id;
  RETURN NEXT is(v_remaining, 0.00::numeric, 'no remaining quantity');

  -- Try reception on fully received (force partiellement_recue to hit v_nb_lignes=0)
  UPDATE purchase.commande SET statut = 'partiellement_recue' WHERE id = v_cmd_id;
  v_result := purchase.post_reception_creer(jsonb_build_object('p_commande_id', v_cmd_id));
  RETURN NEXT ok(v_result LIKE '%réceptionné%', 'nothing left to receive');

  -- Status guard: recue blocks reception
  UPDATE purchase.commande SET statut = 'recue' WHERE id = v_cmd_id;
  v_result := purchase.post_reception_creer(jsonb_build_object('p_commande_id', v_cmd_id));
  RETURN NEXT ok(v_result LIKE '%non réceptionnable%', 'cannot receive already received');

  -- Cleanup
  DELETE FROM purchase.reception_ligne WHERE reception_id IN (SELECT id FROM purchase.reception WHERE commande_id = v_cmd_id);
  DELETE FROM purchase.reception WHERE commande_id = v_cmd_id;
  DELETE FROM purchase.ligne WHERE commande_id = v_cmd_id;
  DELETE FROM purchase.commande WHERE id = v_cmd_id;
  DELETE FROM crm.client WHERE id = v_fournisseur_id;
END;
$function$;
