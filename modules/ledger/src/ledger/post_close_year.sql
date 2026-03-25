CREATE OR REPLACE FUNCTION ledger.post_close_year(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_year integer;
  v_start date;
  v_end date;
  v_total_revenue numeric;
  v_total_expense numeric;
  v_resultat numeric;
  v_draft_count integer;
  v_entry_id integer;
  v_account_120 integer;
BEGIN
  v_year := (p_data->>'year')::integer;
  IF v_year IS NULL THEN RAISE EXCEPTION 'Year required'; END IF;

  IF EXISTS (SELECT 1 FROM ledger.fiscal_year WHERE year = v_year AND closed = true) THEN
    RETURN pgv.toast(pgv.t('ledger.nav_fiscal_year') || ' ' || v_year || ' ' || pgv.t('ledger.err_already_closed'), 'error');
  END IF;

  v_start := make_date(v_year, 1, 1);
  v_end := make_date(v_year, 12, 31);

  SELECT count(*) INTO v_draft_count
    FROM ledger.journal_entry
   WHERE posted = false
     AND entry_date >= v_start AND entry_date <= v_end;

  IF v_draft_count > 0 THEN
    RETURN pgv.toast(v_draft_count || ' ' || pgv.t('ledger.err_drafts_remaining'), 'error');
  END IF;

  SELECT coalesce(sum(CASE WHEN a.type = 'revenue' THEN el.credit - el.debit ELSE 0 END), 0),
         coalesce(sum(CASE WHEN a.type = 'expense' THEN el.debit - el.credit ELSE 0 END), 0)
    INTO v_total_revenue, v_total_expense
    FROM ledger.entry_line el
    JOIN ledger.account a ON a.id = el.account_id
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
   WHERE je.posted = true
     AND je.entry_date >= v_start AND je.entry_date <= v_end;

  v_resultat := v_total_revenue - v_total_expense;

  SELECT id INTO v_account_120 FROM ledger.account WHERE code = '120';
  IF v_account_120 IS NULL THEN RAISE EXCEPTION 'Account 120 (Result) not found'; END IF;

  INSERT INTO ledger.journal_entry (entry_date, reference, description)
  VALUES (v_end, 'CLO-' || v_year, 'Fiscal year close ' || v_year || ' — result ' || to_char(v_resultat, 'FM999 990.00') || ' EUR')
  RETURNING id INTO v_entry_id;

  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  SELECT v_entry_id, a.id, coalesce(sum(el.credit - el.debit), 0), 0, 'Close ' || a.label
    FROM ledger.account a
    JOIN ledger.entry_line el ON el.account_id = a.id
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
   WHERE a.type = 'revenue' AND je.posted = true
     AND je.entry_date >= v_start AND je.entry_date <= v_end
     AND je.id <> v_entry_id
   GROUP BY a.id, a.label
  HAVING coalesce(sum(el.credit - el.debit), 0) <> 0;

  INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
  SELECT v_entry_id, a.id, 0, coalesce(sum(el.debit - el.credit), 0), 'Close ' || a.label
    FROM ledger.account a
    JOIN ledger.entry_line el ON el.account_id = a.id
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
   WHERE a.type = 'expense' AND je.posted = true
     AND je.entry_date >= v_start AND je.entry_date <= v_end
     AND je.id <> v_entry_id
   GROUP BY a.id, a.label
  HAVING coalesce(sum(el.debit - el.credit), 0) <> 0;

  IF v_resultat >= 0 THEN
    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES (v_entry_id, v_account_120, 0, v_resultat, 'Profit ' || v_year);
  ELSE
    INSERT INTO ledger.entry_line (journal_entry_id, account_id, debit, credit, label)
    VALUES (v_entry_id, v_account_120, abs(v_resultat), 0, 'Loss ' || v_year);
  END IF;

  UPDATE ledger.journal_entry SET posted = true WHERE id = v_entry_id;

  INSERT INTO ledger.fiscal_year (year, closed, closed_at, result)
  VALUES (v_year, true, now(), v_resultat)
  ON CONFLICT ON CONSTRAINT fiscal_year_tenant_year_key
  DO UPDATE SET closed = true, closed_at = now(), result = v_resultat;

  RETURN pgv.toast(pgv.t('ledger.toast_exercice_closed') || ' ' || v_year || ' — ' || pgv.t('ledger.stat_result') || ' : ' || to_char(v_resultat, 'FM999 990.00') || ' €')
    || pgv.redirect(pgv.call_ref('get_fiscal_year', jsonb_build_object('p_year', v_year)));
END;
$function$;
