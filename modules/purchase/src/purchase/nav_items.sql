CREATE OR REPLACE FUNCTION purchase.nav_items()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('purchase.nav_dashboard'), 'icon', 'home'),
    jsonb_build_object('href', '/purchase_order', 'label', pgv.t('purchase.nav_orders'), 'icon', 'shopping-cart', 'entity', 'purchase_order', 'uri', 'purchase://purchase_order'),
    jsonb_build_object('href', '/supplier_invoice', 'label', pgv.t('purchase.nav_invoices'), 'icon', 'receipt', 'entity', 'supplier_invoice', 'uri', 'purchase://supplier_invoice'),
    jsonb_build_object('href', '/summary', 'label', pgv.t('purchase.nav_summary'), 'icon', 'bar-chart'),
    jsonb_build_object('href', '/article_prices', 'label', pgv.t('purchase.nav_article_prices'), 'icon', 'tag')
  );
END;
$function$;
