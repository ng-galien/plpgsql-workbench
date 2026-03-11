CREATE OR REPLACE FUNCTION quote.nav_items()
 RETURNS jsonb
 LANGUAGE sql
AS $function$
  SELECT '[{"href":"/","label":"Dashboard","icon":"home"},{"href":"/devis","label":"Devis","icon":"file-text"},{"href":"/facture","label":"Factures","icon":"receipt"}]'::jsonb;
$function$;
