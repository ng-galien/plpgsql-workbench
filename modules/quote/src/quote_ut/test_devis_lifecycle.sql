CREATE OR REPLACE FUNCTION quote_ut.test_devis_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_client_id int;
BEGIN
  UPDATE project.chantier SET devis_id = NULL WHERE devis_id IS NOT NULL;
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;

  SELECT id INTO v_client_id FROM crm.client LIMIT 1;

  -- Créer un brouillon via API
  PERFORM quote.post_devis_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test lifecycle'));
  SELECT id INTO v_id FROM quote.devis ORDER BY id DESC LIMIT 1;

  RETURN NEXT is((SELECT statut FROM quote.devis WHERE id = v_id), 'brouillon', 'Nouveau devis = brouillon');

  -- brouillon -> envoye
  PERFORM quote.post_devis_envoyer(jsonb_build_object('id', v_id));
  RETURN NEXT is((SELECT statut FROM quote.devis WHERE id = v_id), 'envoye', 'Transition brouillon -> envoye');

  -- envoye -> accepte
  PERFORM quote.post_devis_accepter(jsonb_build_object('id', v_id));
  RETURN NEXT is((SELECT statut FROM quote.devis WHERE id = v_id), 'accepte', 'Transition envoye -> accepte');

  -- Transition invalide : accepte -> envoye
  RETURN NEXT throws_ok(
    format('SELECT quote.post_devis_envoyer(''{"id":%s}''::jsonb)', v_id),
    'Transition invalide: accepte -> envoye'
  );

  -- Test refus: nouveau brouillon -> envoye -> refuse
  PERFORM quote.post_devis_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test refus'));
  SELECT id INTO v_id FROM quote.devis ORDER BY id DESC LIMIT 1;

  PERFORM quote.post_devis_envoyer(jsonb_build_object('id', v_id));
  PERFORM quote.post_devis_refuser(jsonb_build_object('id', v_id));
  RETURN NEXT is((SELECT statut FROM quote.devis WHERE id = v_id), 'refuse', 'Transition envoye -> refuse');

  UPDATE project.chantier SET devis_id = NULL WHERE devis_id IS NOT NULL;
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;
END;
$function$;
