CREATE OR REPLACE FUNCTION ledger_ut.test_protect_posted()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_entry_id integer;
  v_line_id integer;
BEGIN
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;

  PERFORM ledger.post_entry_save(jsonb_build_object(
    'reference', 'TEST-PROT', 'description', 'Test protection'
  ));
  SELECT id INTO v_entry_id FROM ledger.journal_entry ORDER BY id DESC LIMIT 1;

  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry_id, 'account_code', '512', 'debit', 200, 'credit', 0
  ));
  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry_id, 'account_code', '601', 'debit', 0, 'credit', 200
  ));
  PERFORM ledger.post_entry_post(jsonb_build_object('id', v_entry_id));

  SELECT id INTO v_line_id FROM ledger.entry_line WHERE journal_entry_id = v_entry_id LIMIT 1;

  RETURN NEXT throws_ok(
    format('UPDATE ledger.journal_entry SET description = ''hack'' WHERE id = %s', v_entry_id),
    'Écriture validée : modification interdite (id=' || v_entry_id || ')'
  );

  RETURN NEXT throws_ok(
    format('DELETE FROM ledger.journal_entry WHERE id = %s', v_entry_id),
    'Écriture validée : suppression interdite (id=' || v_entry_id || ')'
  );

  RETURN NEXT throws_ok(
    format('INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit) VALUES (%s, (SELECT id FROM ledger.account WHERE code = ''512''), 10, 0)', v_entry_id),
    'Écriture validée : modification des lignes interdite'
  );

  RETURN NEXT throws_ok(
    format('UPDATE ledger.entry_line SET debit = 999 WHERE id = %s', v_line_id),
    'Écriture validée : modification des lignes interdite'
  );

  RETURN NEXT throws_ok(
    format('DELETE FROM ledger.entry_line WHERE id = %s', v_line_id),
    'Écriture validée : modification des lignes interdite'
  );

  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
END;
$function$;
