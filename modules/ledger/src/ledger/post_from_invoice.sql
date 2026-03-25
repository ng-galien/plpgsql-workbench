CREATE OR REPLACE FUNCTION ledger.post_from_invoice(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_invoice_id integer;
  v_invoice record;
  v_entry_id integer;
  v_total_ht numeric(12,2);
  v_total_tva numeric(12,2);
  v_total_ttc numeric(12,2);
  v_account_411 integer;
  v_account_4457 integer;
  v_account_706 integer;
BEGIN
  v_invoice_id := (p_data->>'invoice_id')::integer;

  SELECT * INTO v_invoice FROM quote.invoice WHERE id = v_invoice_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Invoice % not found', v_invoice_id; END IF;

  IF EXISTS (SELECT 1 FROM ledger.journal_entry WHERE invoice_id = v_invoice_id) THEN
    RETURN pgv.toast(pgv.t('ledger.err_duplicate_facture'), 'error');
  END IF;

  SELECT coalesce(sum(round(l.quantity * l.unit_price, 2)), 0),
         coalesce(sum(round(l.quantity * l.unit_price * l.tva_rate / 100, 2)), 0)
    INTO v_total_ht, v_total_tva
    FROM quote.line_item l
   WHERE l.invoice_id = v_invoice_id;

  v_total_ttc := v_total_ht + v_total_tva;

  IF v_total_ttc = 0 THEN RAISE EXCEPTION 'Invoice has no amount'; END IF;

  SELECT id INTO v_account_411 FROM ledger.account WHERE code = '411';
  SELECT id INTO v_account_4457 FROM ledger.account WHERE code = '4457';
  SELECT id INTO v_account_706 FROM ledger.account WHERE code = '706';

  INSERT INTO ledger.journal_entry (entry_date, reference, description, invoice_id)
  VALUES (
    coalesce(v_invoice.paid_at::date, CURRENT_DATE),
    'INV-' || v_invoice.number,
    'Invoice ' || v_invoice.number || ' — ' || v_invoice.subject,
    v_invoice_id
  ) RETURNING id INTO v_entry_id;

  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  VALUES (v_entry_id, v_account_411, v_total_ttc, 0, 'Client invoice ' || v_invoice.number);

  IF v_total_tva > 0 THEN
    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES (v_entry_id, v_account_4457, 0, v_total_tva, 'VAT collected invoice ' || v_invoice.number);
  END IF;

  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  VALUES (v_entry_id, v_account_706, 0, v_total_ht, 'Service invoice ' || v_invoice.number);

  RETURN pgv.toast(pgv.t('ledger.toast_entry_from_invoice') || ' ' || pgv.esc(v_invoice.number))
    || pgv.redirect(pgv.call_ref('get_entry', jsonb_build_object('p_id', v_entry_id)));
END;
$function$;
