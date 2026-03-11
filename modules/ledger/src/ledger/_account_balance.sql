CREATE OR REPLACE FUNCTION ledger._account_balance(p_account_id integer, p_date date DEFAULT NULL::date)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_type text;
  v_sign integer;
  v_balance numeric;
BEGIN
  SELECT type INTO v_type FROM ledger.account WHERE id = p_account_id;
  IF NOT FOUND THEN RETURN 0; END IF;

  v_sign := ledger._type_sign(v_type);

  SELECT coalesce(sum(el.debit) - sum(el.credit), 0)
    INTO v_balance
    FROM ledger.entry_line el
    JOIN ledger.journal_entry je ON je.id = el.journal_entry_id
   WHERE el.account_id = p_account_id
     AND je.posted = true
     AND (p_date IS NULL OR je.entry_date <= p_date);

  RETURN v_sign * v_balance;
END;
$function$;
