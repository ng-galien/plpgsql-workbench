CREATE OR REPLACE FUNCTION ledger._period_total(p_type text, p_start date, p_end date)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_sign integer;
  v_total numeric;
BEGIN
  v_sign := ledger._type_sign(p_type);

  SELECT coalesce(sum(el.debit) - sum(el.credit), 0)
    INTO v_total
    FROM ledger.entry_line el
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
    JOIN ledger.account a ON a.id = el.account_id
   WHERE a.type = p_type
     AND je.posted = true
     AND je.entry_date >= p_start
     AND je.entry_date <= p_end;

  RETURN v_sign * v_total;
END;
$function$;
