CREATE OR REPLACE FUNCTION purchase.post_invoice_post(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
  v_invoice record;
  v_tva numeric(12,2);
  v_entry_id int;
  v_ledger_exists boolean;
BEGIN
  SELECT * INTO v_invoice FROM purchase.supplier_invoice WHERE id = v_id;
  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('purchase.err_invoice_not_found'), 'error');
  END IF;
  IF v_invoice.status <> 'paid' THEN
    RETURN pgv.toast(pgv.t('purchase.err_must_pay_first'), 'error');
  END IF;
  IF v_invoice.amount_incl_tax = 0 THEN
    RETURN pgv.toast(pgv.t('purchase.err_no_amount'), 'error');
  END IF;
  IF v_invoice.posted THEN
    RETURN pgv.toast(pgv.t('purchase.err_already_booked'), 'error');
  END IF;

  SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = 'ledger') INTO v_ledger_exists;
  IF NOT v_ledger_exists THEN
    RETURN pgv.toast(pgv.t('purchase.err_no_ledger'), 'error');
  END IF;

  v_tva := v_invoice.amount_incl_tax - v_invoice.amount_excl_tax;

  EXECUTE format(
    $e$INSERT INTO ledger.journal_entry (entry_date, reference, description)
    VALUES (%L, %L, %L) RETURNING id$e$,
    coalesce(v_invoice.invoice_date, CURRENT_DATE),
    'SI-' || v_invoice.supplier_ref,
    'Supplier invoice ' || v_invoice.supplier_ref
  ) INTO v_entry_id;

  -- 601 Purchases — debit excl tax
  EXECUTE format(
    $e$INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES (%s, (SELECT id FROM ledger.account WHERE code = '601'), %s, 0, %L)$e$,
    v_entry_id, v_invoice.amount_excl_tax,
    'Purchase invoice ' || v_invoice.supplier_ref
  );

  -- 4456 Deductible VAT — debit VAT
  IF v_tva > 0 THEN
    EXECUTE format(
      $e$INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
      VALUES (%s, (SELECT id FROM ledger.account WHERE code = '4456'), %s, 0, %L)$e$,
      v_entry_id, v_tva,
      'Deductible VAT invoice ' || v_invoice.supplier_ref
    );
  END IF;

  -- 401 Suppliers — credit incl tax
  EXECUTE format(
    $e$INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES (%s, (SELECT id FROM ledger.account WHERE code = '401'), 0, %s, %L)$e$,
    v_entry_id, v_invoice.amount_incl_tax,
    'Supplier invoice ' || v_invoice.supplier_ref
  );

  UPDATE purchase.supplier_invoice SET posted = true WHERE id = v_id;

  RETURN pgv.toast(pgv.t('purchase.toast_entry_created'))
    || pgv.redirect(pgv.call_ref('get_supplier_invoice', jsonb_build_object('p_id', v_id)));
END;
$function$;
