CREATE OR REPLACE FUNCTION quote_ut.test_post_devis_dupliquer()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client_id int;
  v_devis_id int;
  v_new_id int;
  v_count int;
BEGIN
  -- cleanup
  UPDATE project.chantier SET devis_id = NULL WHERE devis_id IS NOT NULL;
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;

  -- use existing client
  SELECT id INTO v_client_id FROM crm.client LIMIT 1;

  INSERT INTO quote.devis (numero, client_id, objet, statut)
    VALUES ('DEV-2099-001', v_client_id, 'Devis original', 'envoye')
    RETURNING id INTO v_devis_id;
  INSERT INTO quote.ligne (devis_id, description, quantite, prix_unitaire, tva_rate)
    VALUES (v_devis_id, 'Ligne A', 2, 100.00, 20.00),
           (v_devis_id, 'Ligne B', 1, 50.00, 5.50);

  -- duplicate (function uses 'id' key)
  PERFORM quote.post_devis_dupliquer(jsonb_build_object('id', v_devis_id));

  -- new devis created
  SELECT id INTO v_new_id FROM quote.devis WHERE id <> v_devis_id AND client_id = v_client_id;
  RETURN NEXT ok(v_new_id IS NOT NULL, 'duplicate devis created');

  -- statut = brouillon
  RETURN NEXT is(
    (SELECT statut FROM quote.devis WHERE id = v_new_id),
    'brouillon', 'duplicate is brouillon');

  -- lignes copied
  SELECT count(*) INTO v_count FROM quote.ligne WHERE devis_id = v_new_id;
  RETURN NEXT is(v_count, 2, 'lignes copied');

  -- different numero
  RETURN NEXT isnt(
    (SELECT numero FROM quote.devis WHERE id = v_new_id),
    'DEV-2099-001', 'different numero');

  -- error on missing devis
  RETURN NEXT throws_ok(
    'SELECT quote.post_devis_dupliquer(''{"id": 999999}''::jsonb)',
    'P0001', NULL, 'error on missing devis');

  -- cleanup
  UPDATE project.chantier SET devis_id = NULL WHERE devis_id IS NOT NULL;
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;
END;
$function$;
