CREATE OR REPLACE FUNCTION purchase.nav_items()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN '[{"href":"/","label":"Dashboard","icon":"home"},{"href":"/commande","label":"Commandes","icon":"shopping-cart"},{"href":"/facture_fournisseur","label":"Factures","icon":"receipt"},{"href":"/recapitulatif","label":"Récap.","icon":"bar-chart"},{"href":"/article_prix","label":"Prix articles","icon":"tag"}]'::jsonb;
END;
$function$;
