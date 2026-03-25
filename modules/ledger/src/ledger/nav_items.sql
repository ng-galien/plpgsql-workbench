CREATE OR REPLACE FUNCTION ledger.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('ledger.nav_dashboard'), 'icon', 'home'),
    jsonb_build_object('href', '/entries', 'label', pgv.t('ledger.nav_entries'), 'icon', 'list', 'entity', 'journal_entry', 'uri', 'ledger://journal_entry'),
    jsonb_build_object('href', '/accounts', 'label', pgv.t('ledger.nav_accounts'), 'icon', 'book', 'entity', 'account', 'uri', 'ledger://account'),
    jsonb_build_object('href', '/balance', 'label', pgv.t('ledger.nav_balance'), 'icon', 'scale'),
    jsonb_build_object('href', '/fiscal_year', 'label', pgv.t('ledger.nav_fiscal_year'), 'icon', 'calendar'),
    jsonb_build_object('href', '/vat', 'label', pgv.t('ledger.nav_vat'), 'icon', 'percent'),
    jsonb_build_object('href', '/balance_sheet', 'label', pgv.t('ledger.nav_balance_sheet'), 'icon', 'bar-chart')
  );
$function$;
