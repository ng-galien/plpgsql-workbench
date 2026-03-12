CREATE OR REPLACE FUNCTION quote_ut.test_delete_constraints()
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

  -- Devis non-brouillon ne peut pas être supprimé
  PERFORM quote.post_devis_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test delete'));
  SELECT id INTO v_id FROM quote.devis ORDER BY id DESC LIMIT 1;
  PERFORM quote.post_devis_envoyer(jsonb_build_object('id', v_id));

  RETURN NEXT throws_ok(
    format('SELECT quote.post_devis_supprimer(''{"id":%s}''::jsonb)', v_id),
    'Seuls les brouillons peuvent être supprimés'
  );

  -- Devis brouillon peut être supprimé
  PERFORM quote.post_devis_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Brouillon'));
  SELECT id INTO v_id FROM quote.devis WHERE statut = 'brouillon' ORDER BY id DESC LIMIT 1;
  PERFORM quote.post_devis_supprimer(jsonb_build_object('id', v_id));
  RETURN NEXT is((SELECT count(*)::int FROM quote.devis WHERE id = v_id), 0, 'Brouillon supprimé');

  -- Facture envoyée ne peut pas être supprimée (immutabilité légale)
  PERFORM quote.post_facture_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test immuable'));
  SELECT id INTO v_id FROM quote.facture ORDER BY id DESC LIMIT 1;
  PERFORM quote.post_facture_envoyer(jsonb_build_object('id', v_id));

  RETURN NEXT throws_ok(
    format('SELECT quote.post_facture_supprimer(''{"id":%s}''::jsonb)', v_id),
    'Seuls les brouillons peuvent être supprimés'
  );

  UPDATE project.chantier SET devis_id = NULL WHERE devis_id IS NOT NULL;
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;
END;
$function$;
