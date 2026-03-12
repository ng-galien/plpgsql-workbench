CREATE OR REPLACE FUNCTION purchase_ut.test_ligne_supprimer()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_ligne_id int;
  v_result text;
  v_fournisseur_id int;
  v_count int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  INSERT INTO crm.client (type, name, tags)
  VALUES ('company', '_test_suppr_', ARRAY['fournisseur'])
  RETURNING id INTO v_fournisseur_id;

  v_result := purchase.post_commande_save(jsonb_build_object(
    'p_fournisseur_id', v_fournisseur_id,
    'p_objet', 'Test suppression ligne'
  ));
  SELECT id INTO v_id FROM purchase.commande WHERE objet = 'Test suppression ligne';

  -- Add 2 lines
  v_result := purchase.post_ligne_ajouter(jsonb_build_object(
    'p_commande_id', v_id, 'p_description', 'Ligne A', 'p_prix_unitaire', 10.00));
  v_result := purchase.post_ligne_ajouter(jsonb_build_object(
    'p_commande_id', v_id, 'p_description', 'Ligne B', 'p_prix_unitaire', 20.00));

  SELECT count(*)::int INTO v_count FROM purchase.ligne WHERE commande_id = v_id;
  RETURN NEXT is(v_count, 2, '2 lines added');

  -- Delete one
  SELECT id INTO v_ligne_id FROM purchase.ligne WHERE commande_id = v_id ORDER BY sort_order LIMIT 1;
  v_result := purchase.post_ligne_supprimer(jsonb_build_object('p_ligne_id', v_ligne_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'delete line succeeds');

  SELECT count(*)::int INTO v_count FROM purchase.ligne WHERE commande_id = v_id;
  RETURN NEXT is(v_count, 1, '1 line remaining');

  -- Cannot delete on envoyee
  v_result := purchase.post_commande_envoyer(jsonb_build_object('p_id', v_id));
  SELECT id INTO v_ligne_id FROM purchase.ligne WHERE commande_id = v_id LIMIT 1;
  v_result := purchase.post_ligne_supprimer(jsonb_build_object('p_ligne_id', v_ligne_id));
  RETURN NEXT ok(v_result LIKE '%brouillon%', 'cannot delete line on sent order');

  -- Cleanup
  DELETE FROM purchase.ligne WHERE commande_id = v_id;
  DELETE FROM purchase.commande WHERE id = v_id;
  DELETE FROM crm.client WHERE id = v_fournisseur_id;
END;
$function$;
