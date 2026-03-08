CREATE OR REPLACE FUNCTION public_ut.test_classify()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT is(classify(5), 'positive', 'positive case');
  RETURN NEXT is(classify(0), 'zero', 'zero case');
END;
$function$;
