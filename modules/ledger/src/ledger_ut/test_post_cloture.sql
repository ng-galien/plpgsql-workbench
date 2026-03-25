CREATE OR REPLACE FUNCTION ledger_ut.test_post_cloture()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_entry_id integer;
  v_result text;
  v_exercice record;
  v_total_debit numeric;
  v_total_credit numeric;
  v_clo_entry_id integer;
BEGIN
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
  DELETE FROM ledger.fiscal_year;

  -- Create a revenue entry in 2025
  INSERT INTO ledger.journal_entry (entry_date, reference, description)
  VALUES ('2025-06-15', 'FAC-TEST', 'Facture test clôture')
  RETURNING id INTO v_entry_id;

  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  VALUES
    (v_entry_id, (SELECT id FROM ledger.account WHERE code = '411'), 1200.00, 0, 'Client'),
    (v_entry_id, (SELECT id FROM ledger.account WHERE code = '4457'), 0, 200.00, 'TVA'),
    (v_entry_id, (SELECT id FROM ledger.account WHERE code = '706'), 0, 1000.00, 'Prestation');
  UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

  -- Create an expense entry in 2025
  INSERT INTO ledger.journal_entry (entry_date, reference, description)
  VALUES ('2025-03-10', 'ACH-TEST', 'Achat test clôture')
  RETURNING id INTO v_entry_id;

  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  VALUES
    (v_entry_id, (SELECT id FROM ledger.account WHERE code = '601'), 300.00, 0, 'Matériaux'),
    (v_entry_id, (SELECT id FROM ledger.account WHERE code = '512'), 0, 300.00, 'Paiement');
  UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

  -- Clôturer 2025
  v_result := ledger.post_close_year('{"year": 2025}'::jsonb);
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'Clôture 2025 réussie');

  -- Vérifier exercice
  SELECT * INTO v_exercice FROM ledger.fiscal_year WHERE year = 2025;
  RETURN NEXT ok(v_exercice.closed, 'Exercice 2025 marqué clos');
  RETURN NEXT is(v_exercice.result, 700.00, 'Résultat = 1000 - 300 = 700');

  -- Vérifier écriture de clôture équilibrée
  SELECT id INTO v_clo_entry_id FROM ledger.journal_entry WHERE reference = 'CLO-2025';
  RETURN NEXT ok(v_clo_entry_id IS NOT NULL, 'Écriture CLO-2025 créée');

  SELECT sum(debit), sum(credit)
    INTO v_total_debit, v_total_credit
    FROM ledger.entry_line WHERE journal_entry_id = v_clo_entry_id;
  RETURN NEXT is(v_total_debit, v_total_credit, 'Écriture clôture équilibrée');

  -- Double clôture bloquée
  v_result := ledger.post_close_year('{"year": 2025}'::jsonb);
  RETURN NEXT ok(v_result LIKE '%déjà clôturé%', 'Double clôture bloquée');

  -- Cleanup
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
  DELETE FROM ledger.fiscal_year;
END;
$function$;
