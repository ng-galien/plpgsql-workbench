CREATE OR REPLACE FUNCTION banking_ut.test_transfer()
 RETURNS SETOF text
 LANGUAGE plpgsql
 SET search_path TO 'banking_ut', 'banking', 'public'
AS $function$
DECLARE
  v_alice integer;
  v_bob integer;
  v_tx integer;
BEGIN
  INSERT INTO banking.accounts (owner, balance) VALUES ('Alice', 1000.00) RETURNING id INTO v_alice;
  INSERT INTO banking.accounts (owner, balance) VALUES ('Bob', 500.00) RETURNING id INTO v_bob;

  -- Happy path
  v_tx := transfer(v_alice, v_bob, 200.00);
  RETURN NEXT ok(v_tx IS NOT NULL, 'transfer returns tx id');
  RETURN NEXT is(get_balance(v_alice), 800.00, 'sender debited');
  RETURN NEXT is(get_balance(v_bob), 700.00, 'receiver credited');

  -- Same account
  RETURN NEXT throws_ok(
    format('SELECT banking.transfer(%s, %s, 100)', v_alice, v_alice),
    'P0001', 'cannot transfer to same account',
    'rejects same account'
  );

  -- Negative amount
  RETURN NEXT throws_ok(
    format('SELECT banking.transfer(%s, %s, -50)', v_alice, v_bob),
    'P0001', 'amount must be positive',
    'rejects negative amount'
  );

  -- Insufficient funds
  RETURN NEXT throws_ok(
    format('SELECT banking.transfer(%s, %s, 99999)', v_alice, v_bob),
    'P0001', NULL,
    'rejects insufficient funds'
  );

  -- Unknown source
  RETURN NEXT throws_ok(
    format('SELECT banking.transfer(%s, %s, 10)', -999, v_bob),
    'P0001', 'source account -999 not found',
    'rejects unknown source'
  );

  -- Unknown target
  RETURN NEXT throws_ok(
    format('SELECT banking.transfer(%s, %s, 10)', v_alice, -999),
    'P0001', 'target account -999 not found',
    'rejects unknown target'
  );
END;
$function$;
