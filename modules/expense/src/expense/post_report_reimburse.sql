CREATE OR REPLACE FUNCTION expense.post_report_reimburse(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
  v_report record;
  v_total numeric(12,2);
  v_has_ledger boolean;
BEGIN
  IF v_id IS NULL THEN RETURN pgv.toast(pgv.t('expense.err_id_required'), 'error'); END IF;
  SELECT * INTO v_report FROM expense.expense_report WHERE id = v_id AND status = 'validated';
  IF NOT FOUND THEN RETURN pgv.toast(pgv.t('expense.err_not_validated'), 'error'); END IF;
  SELECT coalesce(sum(amount_incl_tax), 0) INTO v_total FROM expense.line WHERE note_id = v_id;
  UPDATE expense.expense_report SET status = 'reimbursed', updated_at = now() WHERE id = v_id;
  SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'ledger') INTO v_has_ledger;
  IF v_has_ledger THEN
    BEGIN
      EXECUTE format('SELECT ledger.post_ecriture_creer(%L::jsonb)',
        jsonb_build_object('journal', 'NDF', 'libelle', 'Reimbursement ' || coalesce(v_report.reference, '#' || v_id),
          'lignes', jsonb_build_array(
            jsonb_build_object('compte', '625000', 'debit', v_total, 'credit', 0),
            jsonb_build_object('compte', '421000', 'debit', 0, 'credit', v_total)))::text);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;
  RETURN pgv.toast(pgv.t('expense.toast_note_reimbursed') || ' (' || to_char(v_total, 'FM999 990.00') || ' EUR).')
    || pgv.redirect('/expense_report?p_id=' || v_id);
END;
$function$;
