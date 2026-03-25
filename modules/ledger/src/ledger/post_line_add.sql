CREATE OR REPLACE FUNCTION ledger.post_line_add(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_entry_id integer;
  v_account_id integer;
  v_debit numeric(12,2);
  v_credit numeric(12,2);
BEGIN
  v_entry_id := (p_data->>'entry_id')::integer;

  IF NOT EXISTS (SELECT 1 FROM ledger.journal_entry WHERE id = v_entry_id AND NOT posted) THEN
    RAISE EXCEPTION 'Écriture introuvable ou déjà validée';
  END IF;

  -- Resolve account by id or code
  IF p_data->>'account_id' IS NOT NULL THEN
    v_account_id := (p_data->>'account_id')::integer;
  ELSIF p_data->>'account_code' IS NOT NULL THEN
    SELECT id INTO v_account_id FROM ledger.account WHERE code = p_data->>'account_code';
    IF NOT FOUND THEN RAISE EXCEPTION 'Compte % introuvable', p_data->>'account_code'; END IF;
  ELSE
    RAISE EXCEPTION 'account_id ou account_code requis';
  END IF;

  v_debit := coalesce((p_data->>'debit')::numeric, 0);
  v_credit := coalesce((p_data->>'credit')::numeric, 0);

  IF v_debit = 0 AND v_credit = 0 THEN
    RAISE EXCEPTION 'Débit ou crédit doit être > 0';
  END IF;

  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  VALUES (v_entry_id, v_account_id, v_debit, v_credit, coalesce(p_data->>'label', ''));

  RETURN pgv.toast(pgv.t('ledger.toast_line_added'))
    || pgv.redirect(pgv.call_ref('get_entry', jsonb_build_object('p_id', v_entry_id)));
END;
$function$;
