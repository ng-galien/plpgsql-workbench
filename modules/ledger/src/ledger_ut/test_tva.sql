CREATE OR REPLACE FUNCTION ledger_ut.test_tva()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_entry_id integer;
  v_html text;
BEGIN
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;

  -- Vente avec TVA collectée
  PERFORM ledger.post_entry_save(jsonb_build_object(
    'entry_date', CURRENT_DATE, 'reference', 'TEST-TVA1', 'description', 'Vente prestation'
  ));
  SELECT id INTO v_entry_id FROM ledger.journal_entry WHERE reference = 'TEST-TVA1';

  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry_id, 'account_code', '411', 'debit', 120, 'credit', 0
  ));
  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry_id, 'account_code', '4457', 'debit', 0, 'credit', 20
  ));
  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry_id, 'account_code', '706', 'debit', 0, 'credit', 100
  ));
  PERFORM ledger.post_entry_post(jsonb_build_object('id', v_entry_id));

  -- Achat avec TVA déductible
  PERFORM ledger.post_entry_save(jsonb_build_object(
    'entry_date', CURRENT_DATE, 'reference', 'TEST-TVA2', 'description', 'Achat matériaux'
  ));
  SELECT id INTO v_entry_id FROM ledger.journal_entry WHERE reference = 'TEST-TVA2';

  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry_id, 'account_code', '601', 'debit', 50, 'credit', 0
  ));
  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry_id, 'account_code', '4456', 'debit', 10, 'credit', 0
  ));
  PERFORM ledger.post_line_add(jsonb_build_object(
    'entry_id', v_entry_id, 'account_code', '512', 'debit', 0, 'credit', 60
  ));
  PERFORM ledger.post_entry_post(jsonb_build_object('id', v_entry_id));

  v_html := ledger.get_vat(jsonb_build_object('p_year', extract(year FROM CURRENT_DATE)::integer, 'p_quarter', extract(quarter FROM CURRENT_DATE)::integer));
  RETURN NEXT ok(v_html LIKE '%20.00%', 'TVA collectée = 20.00');
  RETURN NEXT ok(v_html LIKE '%10.00%', 'TVA déductible = 10.00');
  RETURN NEXT ok(v_html LIKE '%reverser%', 'TVA à reverser (solde positif)');

  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
END;
$function$;
