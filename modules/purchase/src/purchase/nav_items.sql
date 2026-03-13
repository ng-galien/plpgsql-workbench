CREATE OR REPLACE FUNCTION purchase.nav_items()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('purchase.nav_dashboard'), 'icon', 'home'),
    jsonb_build_object('href', '/commande', 'label', pgv.t('purchase.nav_commandes'), 'icon', 'shopping-cart'),
    jsonb_build_object('href', '/facture_fournisseur', 'label', pgv.t('purchase.nav_factures'), 'icon', 'receipt'),
    jsonb_build_object('href', '/recapitulatif', 'label', pgv.t('purchase.nav_recap'), 'icon', 'bar-chart'),
    jsonb_build_object('href', '/article_prix', 'label', pgv.t('purchase.nav_prix_articles'), 'icon', 'tag')
  );
END;
$function$;
