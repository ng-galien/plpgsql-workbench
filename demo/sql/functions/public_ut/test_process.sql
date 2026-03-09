CREATE OR REPLACE FUNCTION public_ut.test_process()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT is(process(3), '...', 'small number gives dots');
  RETURN NEXT is(process(0), '', 'zero gives empty');
END;
$function$;
