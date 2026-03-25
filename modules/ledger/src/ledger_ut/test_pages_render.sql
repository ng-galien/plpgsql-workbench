CREATE OR REPLACE FUNCTION ledger_ut.test_pages_render()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
  v_entry_id integer;
  v_acc_id integer;
BEGIN
  UPDATE ledger.journal_entry SET posted = false WHERE posted = true;
  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
  DELETE FROM ledger.fiscal_year;

  v_html := ledger.get_index();
  RETURN NEXT ok(length(v_html) > 50, 'get_index() retourne du HTML');

  v_html := ledger.get_entries();
  RETURN NEXT ok(length(v_html) > 50, 'get_entries() retourne du HTML');

  v_html := ledger.get_accounts();
  RETURN NEXT ok(length(v_html) > 50, 'get_accounts() retourne du HTML');

  v_html := ledger.get_entry_form();
  RETURN NEXT ok(length(v_html) > 50, 'get_entry_form() retourne du HTML');

  v_html := ledger.get_vat();
  RETURN NEXT ok(length(v_html) > 50, 'get_vat() retourne du HTML');

  v_html := ledger.get_balance_sheet();
  RETURN NEXT ok(length(v_html) > 50, 'get_balance_sheet() retourne du HTML');

  v_html := ledger.get_balance();
  RETURN NEXT ok(length(v_html) > 50, 'get_balance() retourne du HTML');

  v_html := ledger.get_fiscal_year();
  RETURN NEXT ok(length(v_html) > 50, 'get_fiscal_year() retourne du HTML');

  SELECT id INTO v_acc_id FROM ledger.account LIMIT 1;
  v_html := ledger.get_account(v_acc_id);
  RETURN NEXT ok(length(v_html) > 50, 'get_account(id) retourne du HTML');

  v_html := ledger.get_general_ledger(jsonb_build_object('p_account_id', v_acc_id));
  RETURN NEXT ok(length(v_html) > 50, 'get_general_ledger(id) retourne du HTML');

  PERFORM ledger.post_entry_save(jsonb_build_object(
    'reference', 'TEST-PAGE', 'description', 'Test pages'
  ));
  SELECT id INTO v_entry_id FROM ledger.journal_entry ORDER BY id DESC LIMIT 1;
  v_html := ledger.get_entry(v_entry_id);
  RETURN NEXT ok(length(v_html) > 50, 'get_entry(id) retourne du HTML');

  v_html := ledger.get_entry_form(v_entry_id);
  RETURN NEXT ok(length(v_html) > 50, 'get_entry_form(id) retourne du HTML');

  RETURN NEXT ok(ledger.nav_items() IS NOT NULL, 'nav_items() retourne du JSON');
  RETURN NEXT ok(length(ledger.brand()) > 0, 'brand() retourne un label');

  DELETE FROM ledger.entry_line;
  DELETE FROM ledger.journal_entry;
END;
$function$;
