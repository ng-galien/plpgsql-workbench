CREATE OR REPLACE FUNCTION purchase_ut.test_facture_comptabiliser()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cmd_id int;
  v_fac_id int;
  v_result text;
  v_entry_count int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- Setup: create commande + facture + pay it
  INSERT INTO purchase.commande (numero, fournisseur_id, objet, statut)
  VALUES ('CMD-TEST-CPT', (SELECT id FROM crm.client LIMIT 1), 'Test compta', 'envoyee')
  RETURNING id INTO v_cmd_id;

  INSERT INTO purchase.facture_fournisseur
    (commande_id, numero_fournisseur, montant_ht, montant_ttc, date_facture, statut)
  VALUES (v_cmd_id, 'FAF-CPT-001', 1000.00, 1200.00, CURRENT_DATE, 'payee')
  RETURNING id INTO v_fac_id;

  -- Cannot comptabiliser non-payee
  UPDATE purchase.facture_fournisseur SET statut = 'validee' WHERE id = v_fac_id;
  v_result := purchase.post_facture_comptabiliser(jsonb_build_object('p_id', v_fac_id));
  RETURN NEXT ok(v_result LIKE '%doit être payée%', 'cannot comptabilise non-payee');

  -- Restore payee
  UPDATE purchase.facture_fournisseur SET statut = 'payee' WHERE id = v_fac_id;

  -- Count entries before
  SELECT count(*) INTO v_entry_count FROM ledger.journal_entry;

  -- Comptabiliser
  v_result := purchase.post_facture_comptabiliser(jsonb_build_object('p_id', v_fac_id));
  RETURN NEXT ok(v_result LIKE '%success%', 'comptabilisation succeeds');

  -- Verify entry created
  RETURN NEXT ok(
    (SELECT count(*) FROM ledger.journal_entry) = v_entry_count + 1,
    'journal entry created'
  );

  -- Verify lines: 607 debit HT, 44566 debit TVA, 401 credit TTC
  RETURN NEXT ok(
    EXISTS(SELECT 1 FROM ledger.entry_line el
      JOIN ledger.account a ON a.id = el.account_id
     WHERE el.journal_entry_id = (SELECT max(id) FROM ledger.journal_entry)
       AND a.code = '601' AND el.debit = 1000.00),
    '601 debited 1000 HT'
  );

  RETURN NEXT ok(
    EXISTS(SELECT 1 FROM ledger.entry_line el
      JOIN ledger.account a ON a.id = el.account_id
     WHERE el.journal_entry_id = (SELECT max(id) FROM ledger.journal_entry)
       AND a.code = '4456' AND el.debit = 200.00),
    '4456 debited 200 TVA'
  );

  RETURN NEXT ok(
    EXISTS(SELECT 1 FROM ledger.entry_line el
      JOIN ledger.account a ON a.id = el.account_id
     WHERE el.journal_entry_id = (SELECT max(id) FROM ledger.journal_entry)
       AND a.code = '401' AND el.credit = 1200.00),
    '401 credited 1200 TTC'
  );

  -- Verify comptabilisee flag set
  RETURN NEXT ok(
    (SELECT comptabilisee FROM purchase.facture_fournisseur WHERE id = v_fac_id),
    'comptabilisee flag is true'
  );

  -- Cannot comptabilise twice
  v_result := purchase.post_facture_comptabiliser(jsonb_build_object('p_id', v_fac_id));
  RETURN NEXT ok(v_result LIKE '%déjà comptabilisée%', 'cannot comptabilise twice');

  -- Cleanup
  DELETE FROM ledger.entry_line WHERE journal_entry_id = (SELECT max(id) FROM ledger.journal_entry);
  DELETE FROM ledger.journal_entry WHERE id = (SELECT max(id) FROM ledger.journal_entry);
  DELETE FROM purchase.facture_fournisseur WHERE id = v_fac_id;
  DELETE FROM purchase.commande WHERE id = v_cmd_id;
END;
$function$;
