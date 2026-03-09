CREATE OR REPLACE FUNCTION banking.get_balance(p_account_id integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_balance numeric;
BEGIN
  SELECT balance INTO v_balance FROM banking.accounts WHERE id = p_account_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'account % not found', p_account_id;
  END IF;
  RETURN v_balance;
END;
$function$;
