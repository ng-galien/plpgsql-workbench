CREATE OR REPLACE FUNCTION pgv_ut.test_dl()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(pgv.dl('K', 'V') LIKE '%pgv-dl%', 'dl has pgv-dl class');
END;
$function$;
