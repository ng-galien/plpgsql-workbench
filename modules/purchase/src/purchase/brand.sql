CREATE OR REPLACE FUNCTION purchase.brand()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN 'Achats';
END;
$function$;
