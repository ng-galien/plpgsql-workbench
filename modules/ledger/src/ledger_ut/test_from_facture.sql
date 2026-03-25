CREATE OR REPLACE FUNCTION ledger_ut.test_from_facture()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_facture_id integer;
  v_entry_id integer;
  v_line_count integer;
  v_total_debit numeric;
  v_total_credit numeric;
BEGIN
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;

  SELECT f.id INTO v_facture_id
    FROM quote.invoice f
    JOIN quote.line_item l ON l.invoice_id = f.id
   GROUP BY f.id
   HAVING count(*) > 0
   LIMIT 1;

  IF v_facture_id IS NULL THEN
    RETURN NEXT skip('Aucune facture avec lignes dans quote — test ignoré');
    RETURN;
  END IF;

  PERFORM ledger.post_from_invoice(jsonb_build_object('invoice_id', v_facture_id));

  SELECT id INTO v_entry_id FROM ledger.journal_entry ORDER BY id DESC LIMIT 1;

  SELECT count(*), sum(debit), sum(credit)
    INTO v_line_count, v_total_debit, v_total_credit
    FROM ledger.entry_line WHERE journal_entry_id = v_entry_id;

  RETURN NEXT ok(v_line_count >= 2, 'Écriture facture a >= 2 lignes (a ' || v_line_count || ')');
  RETURN NEXT is(v_total_debit, v_total_credit, 'Écriture facture équilibrée : débit = crédit');

  RETURN NEXT ok(
    EXISTS (SELECT 1 FROM ledger.journal_entry WHERE id = v_entry_id AND reference LIKE 'INV-%'),
    'Reference starts with INV-'
  );

  RETURN NEXT ok(
    EXISTS (SELECT 1 FROM ledger.entry_line el JOIN ledger.account a ON a.id = el.account_id
            WHERE el.journal_entry_id = v_entry_id AND a.code = '411' AND el.debit > 0),
    'Ligne 411 Clients en débit'
  );
  RETURN NEXT ok(
    EXISTS (SELECT 1 FROM ledger.entry_line el JOIN ledger.account a ON a.id = el.account_id
            WHERE el.journal_entry_id = v_entry_id AND a.code = '706' AND el.credit > 0),
    'Ligne 706 Prestations en crédit'
  );

  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
END;
$function$;
