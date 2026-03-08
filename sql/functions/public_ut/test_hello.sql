CREATE OR REPLACE FUNCTION public_ut.test_hello()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT is(hello('world'), 'Hello world', 'hello with name');
  RETURN NEXT is(hello(''), 'Hello ', 'hello with empty string');
END;
$function$;
