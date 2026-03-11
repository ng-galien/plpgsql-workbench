CREATE OR REPLACE FUNCTION quote_qa.clean()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM quote.ligne;
  DELETE FROM quote.facture;
  DELETE FROM quote.devis;
  RETURN 'quote_qa.clean: all quote data removed';
END;
$function$;
