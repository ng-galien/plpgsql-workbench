CREATE OR REPLACE FUNCTION purchase_ut.test_post_facture_comptabiliser()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY SELECT * FROM purchase_ut.test_facture_comptabiliser();
END;
$function$;
