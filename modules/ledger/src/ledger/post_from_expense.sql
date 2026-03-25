CREATE OR REPLACE FUNCTION ledger.post_from_expense(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_note_id integer;
  v_montant_ht numeric(12,2);
  v_tva numeric(12,2);
  v_montant_ttc numeric(12,2);
  v_code_comptable text;
  v_libelle text;
  v_entry_id integer;
  v_account_charge integer;
  v_account_4456 integer;
  v_account_421 integer;
BEGIN
  v_note_id := (p_data->>'note_id')::integer;
  v_montant_ht := (p_data->>'montant_ht')::numeric;
  v_tva := coalesce((p_data->>'tva')::numeric, 0);
  v_code_comptable := coalesce(p_data->>'code_comptable', '625');
  v_libelle := coalesce(p_data->>'libelle', 'Note de frais #' || v_note_id);

  IF v_note_id IS NULL THEN RAISE EXCEPTION 'note_id requis'; END IF;
  IF v_montant_ht IS NULL OR v_montant_ht <= 0 THEN RAISE EXCEPTION 'montant_ht requis et > 0'; END IF;

  v_montant_ttc := v_montant_ht + v_tva;

  -- Guard: doublon interdit
  IF EXISTS (SELECT 1 FROM ledger.journal_entry WHERE expense_note_id = v_note_id) THEN
    RETURN pgv.toast(pgv.t('ledger.err_duplicate_expense'), 'error');
  END IF;

  -- Resolve account IDs
  SELECT id INTO v_account_charge FROM ledger.account WHERE code = v_code_comptable;
  IF v_account_charge IS NULL THEN RAISE EXCEPTION 'Compte % introuvable dans le plan comptable', v_code_comptable; END IF;

  SELECT id INTO v_account_4456 FROM ledger.account WHERE code = '4456';
  SELECT id INTO v_account_421 FROM ledger.account WHERE code = '421';

  IF v_account_421 IS NULL THEN RAISE EXCEPTION 'Compte 421 Personnel introuvable'; END IF;

  -- Create journal entry
  INSERT INTO ledger.journal_entry (entry_date, reference, description, expense_note_id)
  VALUES (
    CURRENT_DATE,
    'NDF-' || v_note_id,
    v_libelle,
    v_note_id
  ) RETURNING id INTO v_entry_id;

  -- 6xx Charge — débit HT
  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  VALUES (v_entry_id, v_account_charge, v_montant_ht, 0, v_libelle);

  -- 4456 TVA déductible — débit TVA (si > 0)
  IF v_tva > 0 THEN
    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES (v_entry_id, v_account_4456, v_tva, 0, 'TVA déductible NDF-' || v_note_id);
  END IF;

  -- 421 Personnel — crédit TTC (dette envers le salarié)
  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  VALUES (v_entry_id, v_account_421, 0, v_montant_ttc, 'Remboursement NDF-' || v_note_id);

  RETURN pgv.toast(pgv.t('ledger.toast_entry_from_expense') || ' — ' || pgv.esc(v_libelle))
    || pgv.redirect(pgv.call_ref('get_entry', jsonb_build_object('p_id', v_entry_id)));
END;
$function$;
