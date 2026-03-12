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
  DELETE FROM ledger.exercice;

  v_html := ledger.get_index();
  RETURN NEXT ok(length(v_html) > 50, 'get_index() retourne du HTML');

  v_html := ledger.get_entries();
  RETURN NEXT ok(length(v_html) > 50, 'get_entries() retourne du HTML');

  v_html := ledger.get_accounts();
  RETURN NEXT ok(length(v_html) > 50, 'get_accounts() retourne du HTML');

  v_html := ledger.get_entry_form();
  RETURN NEXT ok(length(v_html) > 50, 'get_entry_form() retourne du HTML');

  v_html := ledger.get_tva();
  RETURN NEXT ok(length(v_html) > 50, 'get_tva() retourne du HTML');

  v_html := ledger.get_bilan();
  RETURN NEXT ok(length(v_html) > 50, 'get_bilan() retourne du HTML');

  v_html := ledger.get_balance();
  RETURN NEXT ok(length(v_html) > 50, 'get_balance() retourne du HTML');

  v_html := ledger.get_exercice();
  RETURN NEXT ok(length(v_html) > 50, 'get_exercice() retourne du HTML');

  SELECT id INTO v_acc_id FROM ledger.account LIMIT 1;
  v_html := ledger.get_account(v_acc_id);
  RETURN NEXT ok(length(v_html) > 50, 'get_account(id) retourne du HTML');

  v_html := ledger.get_grand_livre(v_acc_id);
  RETURN NEXT ok(length(v_html) > 50, 'get_grand_livre(id) retourne du HTML');

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
