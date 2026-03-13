CREATE OR REPLACE FUNCTION quote.nav_items()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('quote.nav_dashboard'), 'icon', 'home'),
    jsonb_build_object('href', '/devis', 'label', pgv.t('quote.nav_devis'), 'icon', 'file-text'),
    jsonb_build_object('href', '/facture', 'label', pgv.t('quote.nav_factures'), 'icon', 'receipt')
  );
END;
$function$;
