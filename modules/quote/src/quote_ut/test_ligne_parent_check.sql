CREATE OR REPLACE FUNCTION quote_ut.test_ligne_parent_check()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_devis_id int;
  v_client_id int;
BEGIN
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;

  SELECT id INTO v_client_id FROM crm.client LIMIT 1;

  PERFORM quote.post_devis_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test XOR'));
  SELECT id INTO v_devis_id FROM quote.devis ORDER BY id DESC LIMIT 1;

  -- Ligne sans parent -> erreur XOR
  RETURN NEXT throws_ok(
    'INSERT INTO quote.ligne (description, prix_unitaire) VALUES (''Orphan'', 10)',
    23514,  -- check_violation
    'new row for relation "ligne" violates check constraint "ligne_parent_xor"'
  );

  -- Ligne avec les deux parents -> erreur XOR
  RETURN NEXT throws_ok(
    format('INSERT INTO quote.ligne (devis_id, facture_id, description, prix_unitaire) VALUES (%s, 1, ''Both'', 10)', v_devis_id),
    23514
  );

  -- Ajout ligne sur devis non-brouillon -> erreur
  PERFORM quote.post_devis_envoyer(jsonb_build_object('id', v_devis_id));
  RETURN NEXT throws_ok(
    format('SELECT quote.post_ligne_ajouter(''{"devis_id":%s,"description":"Test","prix_unitaire":10}''::jsonb)', v_devis_id),
    'Lignes modifiables uniquement sur un brouillon'
  );

  DELETE FROM quote.ligne;
  DELETE FROM quote.devis;
END;
$function$;
