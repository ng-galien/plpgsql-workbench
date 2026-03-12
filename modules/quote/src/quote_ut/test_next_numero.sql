CREATE OR REPLACE FUNCTION quote_ut.test_next_numero()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_num1 text;
  v_num2 text;
  v_year text := to_char(now(), 'YYYY');
  v_client_id int;
BEGIN
  -- Cleanup (respect FK order)
  UPDATE project.chantier SET devis_id = NULL WHERE devis_id IS NOT NULL;
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;

  SELECT id INTO v_client_id FROM crm.client LIMIT 1;

  -- Créer un premier devis via post_devis_save
  PERFORM quote.post_devis_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test 1'));
  SELECT numero INTO v_num1 FROM quote.devis ORDER BY id DESC LIMIT 1;
  RETURN NEXT is(v_num1, 'DEV-' || v_year || '-001', 'Premier devis = 001');

  -- Deuxième devis
  PERFORM quote.post_devis_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test 2'));
  SELECT numero INTO v_num2 FROM quote.devis ORDER BY id DESC LIMIT 1;
  RETURN NEXT is(v_num2, 'DEV-' || v_year || '-002', 'Deuxième devis = 002');

  -- Première facture
  PERFORM quote.post_facture_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Facture 1'));
  SELECT numero INTO v_num1 FROM quote.facture ORDER BY id DESC LIMIT 1;
  RETURN NEXT is(v_num1, 'FAC-' || v_year || '-001', 'Première facture = 001');

  -- Test MAX+1 robustesse: supprimer le premier devis, le suivant doit être 003
  DELETE FROM quote.devis WHERE numero = 'DEV-' || v_year || '-001';
  PERFORM quote.post_devis_save(jsonb_build_object('client_id', v_client_id, 'objet', 'Test 3'));
  SELECT numero INTO v_num1 FROM quote.devis ORDER BY id DESC LIMIT 1;
  RETURN NEXT is(v_num1, 'DEV-' || v_year || '-003', 'Après suppression = 003 (MAX+1, pas count)');

  -- Cleanup
  UPDATE project.chantier SET devis_id = NULL WHERE devis_id IS NOT NULL;
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;
END;
$function$;
