CREATE OR REPLACE FUNCTION purchase_ut.test_post_reception_creer()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY SELECT * FROM purchase_ut.test_reception_partielle();
END;
$function$;
