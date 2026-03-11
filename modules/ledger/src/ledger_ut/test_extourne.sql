CREATE OR REPLACE FUNCTION ledger_ut.test_extourne()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_entry1_id integer;
  v_entry2_id integer;
  v_html text;
  v_acc_512 integer;
BEGIN
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;

  SELECT id INTO v_acc_512 FROM ledger.account WHERE code = '512';

  -- Écriture originale : achat 601 débit 500, 512 crédit 500
  PERFORM ledger.post_entry_save(jsonb_build_object(
    'reference', 'TEST-EXT1', 'description', 'Achat original'
  ));
  SELECT id INTO v_entry1_id FROM ledger.journal_entry ORDER BY id DESC LIMIT 1;

  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry1_id, 'account_code', '601', 'debit', 500, 'credit', 0
  ));
  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry1_id, 'account_code', '512', 'debit', 0, 'credit', 500
  ));
  PERFORM ledger.post_entry_post(jsonb_build_object('id', v_entry1_id));

  v_html := ledger.get_account(v_acc_512);
  RETURN NEXT ok(v_html LIKE '%500.00%', 'Banque affiche solde après achat');

  -- Extourne : sens inversé
  PERFORM ledger.post_entry_save(jsonb_build_object(
    'reference', 'TEST-EXT2', 'description', 'Extourne achat'
  ));
  SELECT id INTO v_entry2_id FROM ledger.journal_entry WHERE reference = 'TEST-EXT2';

  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry2_id, 'account_code', '512', 'debit', 500, 'credit', 0
  ));
  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry2_id, 'account_code', '601', 'debit', 0, 'credit', 500
  ));
  PERFORM ledger.post_entry_post(jsonb_build_object('id', v_entry2_id));

  v_html := ledger.get_account(v_acc_512);
  RETURN NEXT ok(v_html LIKE '%0.00%', 'Après extourne, solde banque = 0');

  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
END;
$function$;
