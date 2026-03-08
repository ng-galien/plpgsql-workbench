CREATE OR REPLACE FUNCTION banking_ut.test_get_balance()
 RETURNS SETOF text
 LANGUAGE plpgsql
 SET search_path TO 'banking_ut', 'banking', 'public'
AS $function$
DECLARE
  v_id integer;
BEGIN
  INSERT INTO banking.accounts (owner, balance) VALUES ('Alice', 100.00) RETURNING id INTO v_id;

  RETURN NEXT is(get_balance(v_id), 100.00, 'returns correct balance');
  RETURN NEXT throws_ok(
    format('SELECT banking.get_balance(%s)', -999),
    'P0001', 'account -999 not found',
    'throws on unknown account'
  );
END;
$function$;
