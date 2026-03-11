CREATE OR REPLACE FUNCTION ledger_ut.test_account_balance()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_entry_id integer;
  v_acc_512 integer;
  v_acc_706 integer;
  v_html text;
BEGIN
  -- Cleanup: unpost first, then delete
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;

  SELECT id INTO v_acc_512 FROM ledger.account WHERE code = '512';
  SELECT id INTO v_acc_706 FROM ledger.account WHERE code = '706';

  -- Create and post a balanced entry
  INSERT INTO ledger.journal_entry (entry_date, reference, description)
  VALUES (CURRENT_DATE, 'TEST-BAL', 'Test balance')
  RETURNING id INTO v_entry_id;

  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit)
  VALUES (v_entry_id, v_acc_512, 1000, 0),
         (v_entry_id, v_acc_706, 0, 1000);

  UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

  -- Verify via get_account page
  v_html := ledger.get_account(v_acc_512);
  RETURN NEXT ok(v_html LIKE '%1 000.00%', 'Banque (asset) affiche solde 1 000.00');

  v_html := ledger.get_account(v_acc_706);
  RETURN NEXT ok(v_html LIKE '%1 000.00%', 'Prestations (revenue) affiche solde 1 000.00');

  v_html := ledger.get_index();
  RETURN NEXT ok(v_html LIKE '%1 000.00%', 'Dashboard affiche solde banque');

  -- Cleanup
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
END;
$function$;
