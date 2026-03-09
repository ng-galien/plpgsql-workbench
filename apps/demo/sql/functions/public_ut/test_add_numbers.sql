CREATE OR REPLACE FUNCTION public_ut.test_add_numbers()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT is(add_numbers(1, 2), 3, 'basic addition');
  RETURN NEXT is(add_numbers(0, 0), 0, 'zero plus zero');
  RETURN NEXT is(add_numbers(-1, 1), 0, 'negative plus positive');
END;
$function$;
