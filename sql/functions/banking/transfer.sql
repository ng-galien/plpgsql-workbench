CREATE OR REPLACE FUNCTION banking.transfer(p_from integer, p_to integer, p_amount numeric)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_balance numeric;
  v_tx_id integer;
BEGIN
  -- Validate
  IF p_from = p_to THEN
    RAISE EXCEPTION 'cannot transfer to same account';
  END IF;

  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'amount must be positive';
  END IF;

  -- Check balance
  SELECT balance INTO v_balance FROM banking.accounts WHERE id = p_from FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'source account % not found', p_from;
  END IF;

  IF v_balance < p_amount THEN
    RAISE EXCEPTION 'insufficient funds: have %, need %', v_balance, p_amount;
  END IF;

  -- Verify target exists
  PERFORM 1 FROM banking.accounts WHERE id = p_to FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'target account % not found', p_to;
  END IF;

  -- Execute transfer
  UPDATE banking.accounts SET balance = balance - p_amount WHERE id = p_from;
  UPDATE banking.accounts SET balance = balance + p_amount WHERE id = p_to;

  INSERT INTO banking.transactions (from_account_id, to_account_id, amount)
  VALUES (p_from, p_to, p_amount)
  RETURNING id INTO v_tx_id;

  RETURN v_tx_id;
END;
$function$;
