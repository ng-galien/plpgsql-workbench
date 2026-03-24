CREATE OR REPLACE FUNCTION ledger.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('ledger.nav_dashboard'), 'icon', 'home'),
    jsonb_build_object('href', '/entries', 'label', pgv.t('ledger.nav_entries'), 'icon', 'list', 'entity', 'journal_entry'),
    jsonb_build_object('href', '/accounts', 'label', pgv.t('ledger.nav_accounts'), 'icon', 'book', 'entity', 'account'),
    jsonb_build_object('href', '/balance', 'label', pgv.t('ledger.nav_balance'), 'icon', 'scale'),
    jsonb_build_object('href', '/exercice', 'label', pgv.t('ledger.nav_exercice'), 'icon', 'calendar'),
    jsonb_build_object('href', '/tva', 'label', pgv.t('ledger.nav_tva'), 'icon', 'percent'),
    jsonb_build_object('href', '/bilan', 'label', pgv.t('ledger.nav_bilan'), 'icon', 'bar-chart')
  );
$function$;
