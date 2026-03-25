CREATE OR REPLACE FUNCTION quote.nav_items()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('quote.nav_dashboard'), 'icon', 'home'),
    jsonb_build_object('href', '/estimate', 'label', pgv.t('quote.nav_estimates'), 'icon', 'file-text', 'entity', 'estimate'),
    jsonb_build_object('href', '/invoice', 'label', pgv.t('quote.nav_invoices'), 'icon', 'receipt', 'entity', 'invoice')
  );
END;
$function$;
