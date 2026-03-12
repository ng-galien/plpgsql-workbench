CREATE OR REPLACE FUNCTION ledger_ut.test_from_expense()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_entry_id integer;
  v_line_count integer;
  v_total_debit numeric;
  v_total_credit numeric;
  v_ref text;
BEGIN
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;

  -- Create expense entry: 100 HT + 20 TVA = 120 TTC, catégorie déplacements
  v_result := ledger.post_from_expense(jsonb_build_object(
    'note_id', 999,
    'montant_ht', 100,
    'tva', 20,
    'code_comptable', '625',
    'libelle', 'Déplacement chantier Bordeaux'
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'Écriture NDF créée avec succès');

  SELECT id, reference INTO v_entry_id, v_ref FROM ledger.journal_entry WHERE expense_note_id = 999;
  RETURN NEXT ok(v_entry_id IS NOT NULL, 'Écriture liée à expense_note_id=999');
  RETURN NEXT ok(v_ref = 'NDF-999', 'Référence = NDF-999');

  SELECT count(*) INTO v_line_count FROM ledger.entry_line WHERE journal_entry_id = v_entry_id;
  RETURN NEXT ok(v_line_count = 3, 'Écriture a 3 lignes (charge + TVA + personnel)');

  SELECT sum(debit), sum(credit) INTO v_total_debit, v_total_credit
    FROM ledger.entry_line WHERE journal_entry_id = v_entry_id;
  RETURN NEXT ok(v_total_debit = v_total_credit, 'Écriture équilibrée : débit = crédit');
  RETURN NEXT ok(v_total_debit = 120, 'Total = 120 TTC (100 HT + 20 TVA)');

  -- Doublon interdit
  v_result := ledger.post_from_expense(jsonb_build_object(
    'note_id', 999, 'montant_ht', 50
  ));
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'Doublon expense_note_id interdit');

  -- Sans TVA = 2 lignes
  v_result := ledger.post_from_expense(jsonb_build_object(
    'note_id', 1000,
    'montant_ht', 50,
    'code_comptable', '625',
    'libelle', 'Péage autoroute'
  ));
  SELECT id INTO v_entry_id FROM ledger.journal_entry WHERE expense_note_id = 1000;
  SELECT count(*) INTO v_line_count FROM ledger.entry_line WHERE journal_entry_id = v_entry_id;
  RETURN NEXT ok(v_line_count = 2, 'Sans TVA = 2 lignes (charge + personnel)');

  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
END;
$function$;
