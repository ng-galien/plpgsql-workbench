CREATE OR REPLACE FUNCTION quote_ut.test_devis_facturer()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_devis_id int;
  v_facture_id int;
  v_client_id int;
  v_nb_lignes_d int;
  v_nb_lignes_f int;
  v_ttc_d numeric(12,2);
  v_ttc_f numeric(12,2);
BEGIN
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;

  SELECT id INTO v_client_id FROM crm.client LIMIT 1;

  -- Créer devis + lignes
  PERFORM quote.post_devis_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Travaux salle de bain'));
  SELECT id INTO v_devis_id FROM quote.devis ORDER BY id DESC LIMIT 1;

  PERFORM quote.post_ligne_ajouter(jsonb_build_object('devis_id', v_devis_id, 'description', 'Main oeuvre', 'quantite', 8, 'unite', 'h', 'prix_unitaire', 45, 'tva_rate', 10));
  PERFORM quote.post_ligne_ajouter(jsonb_build_object('devis_id', v_devis_id, 'description', 'Fournitures', 'quantite', 1, 'unite', 'forfait', 'prix_unitaire', 350, 'tva_rate', 20));

  -- Facturer un brouillon -> erreur
  RETURN NEXT throws_ok(
    format('SELECT quote.post_devis_facturer(''{"id":%s}''::jsonb)', v_devis_id),
    'Seuls les devis acceptés peuvent être facturés'
  );

  -- Cycle: envoyer -> accepter -> facturer
  PERFORM quote.post_devis_envoyer(jsonb_build_object('id', v_devis_id));
  PERFORM quote.post_devis_accepter(jsonb_build_object('id', v_devis_id));
  PERFORM quote.post_devis_facturer(jsonb_build_object('id', v_devis_id));

  SELECT id INTO v_facture_id FROM quote.facture WHERE devis_id = v_devis_id;
  RETURN NEXT isnt(v_facture_id, NULL, 'Facture créée depuis devis');

  -- Vérifier que les lignes ont été copiées
  SELECT count(*)::int INTO v_nb_lignes_d FROM quote.ligne WHERE devis_id = v_devis_id;
  SELECT count(*)::int INTO v_nb_lignes_f FROM quote.ligne WHERE facture_id = v_facture_id;
  RETURN NEXT is(v_nb_lignes_f, v_nb_lignes_d, 'Lignes copiées dans la facture');

  -- Vérifier montants identiques via SQL direct
  SELECT sum(round(quantite * prix_unitaire, 2) + round(quantite * prix_unitaire * tva_rate / 100, 2))
    INTO v_ttc_d FROM quote.ligne WHERE devis_id = v_devis_id;
  SELECT sum(round(quantite * prix_unitaire, 2) + round(quantite * prix_unitaire * tva_rate / 100, 2))
    INTO v_ttc_f FROM quote.ligne WHERE facture_id = v_facture_id;
  RETURN NEXT is(v_ttc_f, v_ttc_d, 'TTC devis = TTC facture');

  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;
END;
$function$;
