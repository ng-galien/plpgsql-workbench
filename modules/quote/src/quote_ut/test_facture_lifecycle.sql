CREATE OR REPLACE FUNCTION quote_ut.test_facture_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_client_id int;
BEGIN
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;

  SELECT id INTO v_client_id FROM crm.client LIMIT 1;

  PERFORM quote.post_facture_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test lifecycle'));
  SELECT id INTO v_id FROM quote.facture ORDER BY id DESC LIMIT 1;

  RETURN NEXT is((SELECT statut FROM quote.facture WHERE id = v_id), 'brouillon', 'Nouvelle facture = brouillon');

  -- brouillon -> envoyee
  PERFORM quote.post_facture_envoyer(jsonb_build_object('id', v_id));
  RETURN NEXT is((SELECT statut FROM quote.facture WHERE id = v_id), 'envoyee', 'Transition brouillon -> envoyee');

  -- envoyee -> payee
  PERFORM quote.post_facture_payer(jsonb_build_object('id', v_id));
  RETURN NEXT is((SELECT statut FROM quote.facture WHERE id = v_id), 'payee', 'Transition envoyee -> payee');
  RETURN NEXT isnt((SELECT paid_at FROM quote.facture WHERE id = v_id), NULL, 'paid_at renseigné');

  -- Transition invalide
  RETURN NEXT throws_ok(
    format('SELECT quote.post_facture_envoyer(''{"id":%s}''::jsonb)', v_id),
    'Transition invalide: payee -> envoyee'
  );

  -- Suppression non-brouillon impossible
  RETURN NEXT throws_ok(
    format('SELECT quote.post_facture_supprimer(''{"id":%s}''::jsonb)', v_id),
    'Seuls les brouillons peuvent être supprimés'
  );

  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;
END;
$function$;
