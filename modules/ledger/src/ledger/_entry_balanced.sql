CREATE OR REPLACE FUNCTION ledger._entry_balanced(p_entry_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_count integer;
  v_sum_debit numeric(12,2);
  v_sum_credit numeric(12,2);
BEGIN
  SELECT count(*), coalesce(sum(debit), 0), coalesce(sum(credit), 0)
    INTO v_count, v_sum_debit, v_sum_credit
    FROM ledger.entry_line
   WHERE journal_entry_id = p_entry_id;

  IF v_count < 2 THEN RETURN false; END IF;
  RETURN v_sum_debit = v_sum_credit;
END;
$function$;
