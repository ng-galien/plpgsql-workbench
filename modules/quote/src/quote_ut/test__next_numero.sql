CREATE OR REPLACE FUNCTION quote_ut.test__next_numero()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY SELECT * FROM quote_ut.test_next_numero();
  -- Branche ELSE: préfixe invalide
  RETURN NEXT throws_ok(
    'SELECT quote._next_numero(''XXX'')',
    'Préfixe invalide: XXX'
  );
END;
$function$;
