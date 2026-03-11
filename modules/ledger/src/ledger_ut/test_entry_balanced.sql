CREATE OR REPLACE FUNCTION ledger_ut.test_entry_balanced()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_entry_id integer;
BEGIN
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;

  PERFORM ledger.post_entry_save(jsonb_build_object(
    'reference', 'TEST-EQ', 'description', 'Test équilibre'
  ));
  SELECT id INTO v_entry_id FROM ledger.journal_entry ORDER BY id DESC LIMIT 1;

  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry_id, 'account_code', '512', 'debit', 100, 'credit', 0
  ));

  RETURN NEXT throws_ok(
    format('SELECT ledger.post_entry_post(''{"id":%s}''::jsonb)', v_entry_id),
    'Écriture déséquilibrée : impossible de valider'
  );

  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry_id, 'account_code', '601', 'debit', 0, 'credit', 100
  ));

  RETURN NEXT lives_ok(
    format('SELECT ledger.post_entry_post(''{"id":%s}''::jsonb)', v_entry_id),
    'Écriture équilibrée : validation OK'
  );

  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
END;
$function$;
