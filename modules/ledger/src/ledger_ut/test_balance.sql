CREATE OR REPLACE FUNCTION ledger_ut.test_balance()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_entry_id integer;
BEGIN
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;

  -- Create a posted entry
  INSERT INTO ledger.journal_entry (entry_date, reference, description)
  VALUES ('2026-01-15', 'BAL-TEST', 'Test balance')
  RETURNING id INTO v_entry_id;

  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  VALUES
    (v_entry_id, (SELECT id FROM ledger.account WHERE code = '411'), 1200.00, 0, 'Client'),
    (v_entry_id, (SELECT id FROM ledger.account WHERE code = '706'), 0, 1200.00, 'Prestation');
  UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

  v_html := ledger.get_balance(2026);
  RETURN NEXT ok(length(v_html) > 100, 'get_balance() retourne du HTML substantiel');
  RETURN NEXT ok(v_html LIKE '%411%', 'Balance contient compte 411');
  RETURN NEXT ok(v_html LIKE '%706%', 'Balance contient compte 706');
  RETURN NEXT ok(v_html LIKE '%quilibre OK%', 'Balance affiche Équilibre OK');

  -- Cleanup
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
END;
$function$;
