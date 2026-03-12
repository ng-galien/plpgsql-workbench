CREATE OR REPLACE FUNCTION quote_ut.test_post_ligne_ajouter()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_devis_id int;
  v_facture_id int;
  v_client_id int;
  v_count int;
BEGIN
  UPDATE project.chantier SET devis_id = NULL WHERE devis_id IS NOT NULL;
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;

  SELECT id INTO v_client_id FROM crm.client LIMIT 1;

  -- Ajout ligne sur devis brouillon
  PERFORM quote.post_devis_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test ligne'));
  SELECT id INTO v_devis_id FROM quote.devis ORDER BY id DESC LIMIT 1;

  PERFORM quote.post_ligne_ajouter(jsonb_build_object(
    'devis_id', v_devis_id, 'description', 'Prestation', 'quantite', 2, 'unite', 'h', 'prix_unitaire', 50, 'tva_rate', 20
  ));
  SELECT count(*)::int INTO v_count FROM quote.ligne WHERE devis_id = v_devis_id;
  RETURN NEXT is(v_count, 1, 'Ligne ajoutée sur devis');

  -- Ajout ligne sur facture brouillon
  PERFORM quote.post_facture_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test ligne fac'));
  SELECT id INTO v_facture_id FROM quote.facture ORDER BY id DESC LIMIT 1;

  PERFORM quote.post_ligne_ajouter(jsonb_build_object(
    'facture_id', v_facture_id, 'description', 'Service', 'quantite', 1, 'unite', 'forfait', 'prix_unitaire', 100, 'tva_rate', 20
  ));
  SELECT count(*)::int INTO v_count FROM quote.ligne WHERE facture_id = v_facture_id;
  RETURN NEXT is(v_count, 1, 'Ligne ajoutée sur facture');

  -- Ajout sans parent -> erreur
  RETURN NEXT throws_ok(
    'SELECT quote.post_ligne_ajouter(''{"description":"Orphan","prix_unitaire":10}''::jsonb)',
    'devis_id ou facture_id requis'
  );

  -- Ajout sur devis non-brouillon -> erreur
  PERFORM quote.post_devis_envoyer(jsonb_build_object('id', v_devis_id));
  RETURN NEXT throws_ok(
    format('SELECT quote.post_ligne_ajouter(''{"devis_id":%s,"description":"X","prix_unitaire":10}''::jsonb)', v_devis_id),
    'Lignes modifiables uniquement sur un brouillon'
  );

  -- Ajout sur facture non-brouillon -> erreur
  PERFORM quote.post_facture_envoyer(jsonb_build_object('id', v_facture_id));
  RETURN NEXT throws_ok(
    format('SELECT quote.post_ligne_ajouter(''{"facture_id":%s,"description":"X","prix_unitaire":10}''::jsonb)', v_facture_id),
    'Lignes modifiables uniquement sur un brouillon'
  );

  UPDATE project.chantier SET devis_id = NULL WHERE devis_id IS NOT NULL;
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;
END;
$function$;
