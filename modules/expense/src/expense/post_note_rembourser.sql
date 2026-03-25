CREATE OR REPLACE FUNCTION expense.post_note_rembourser(p_params jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_params->>'id')::int;
  v_note record;
  v_total_ttc numeric(12,2);
  v_has_ledger boolean;
BEGIN
  IF v_id IS NULL THEN
    RETURN pgv.toast(pgv.t('expense.err_id_requis'), 'error');
  END IF;

  SELECT * INTO v_note FROM expense.note WHERE id = v_id AND statut = 'validee';
  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('expense.err_not_validee'), 'error');
  END IF;

  SELECT coalesce(sum(montant_ttc), 0) INTO v_total_ttc FROM expense.ligne WHERE note_id = v_id;

  UPDATE expense.note SET statut = 'remboursee', updated_at = now() WHERE id = v_id;

  SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'ledger') INTO v_has_ledger;
  IF v_has_ledger THEN
    BEGIN
      EXECUTE format(
        'SELECT ledger.post_ecriture_creer(%L::jsonb)',
        jsonb_build_object(
          'journal', 'NDF',
          'libelle', 'Remboursement ' || coalesce(v_note.reference, '#' || v_id),
          'lignes', jsonb_build_array(
            jsonb_build_object('compte', '625000', 'debit', v_total_ttc, 'credit', 0),
            jsonb_build_object('compte', '421000', 'debit', 0, 'credit', v_total_ttc)
          )
        )::text
      );
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN pgv.toast(pgv.t('expense.toast_note_remboursee') || ' (' || to_char(v_total_ttc, 'FM999 990.00') || ' EUR).')
    || pgv.redirect('/note?p_id=' || v_id);
END;
$function$;
