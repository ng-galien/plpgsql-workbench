CREATE OR REPLACE FUNCTION expense_ut.test_pages_render()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_html text;
BEGIN
  -- brand
  v_html := expense.brand();
  RETURN NEXT ok(v_html = 'Notes de frais', 'brand returns label');

  -- nav_items
  RETURN NEXT ok(expense.nav_items() IS NOT NULL, 'nav_items returns jsonb');

  -- get_index (empty)
  v_html := expense.get_index();
  RETURN NEXT ok(v_html LIKE '%pgv-stat%', 'index has stats');
  RETURN NEXT ok(v_html LIKE '%Aucune note%' OR v_html LIKE '%md%', 'index has empty or table');

  -- get_notes
  v_html := expense.get_notes();
  RETURN NEXT ok(v_html IS NOT NULL, 'get_notes renders');

  -- get_categories
  v_html := expense.get_categories();
  RETURN NEXT ok(v_html LIKE '%Repas%', 'categories lists Repas');

  -- get_note_form
  v_html := expense.get_note_form();
  RETURN NEXT ok(v_html LIKE '%post_note_creer%', 'note_form has rpc');

  -- get_note 404
  v_html := expense.get_note(999999);
  RETURN NEXT ok(v_html LIKE '%introuvable%', 'get_note 404');
END;
$function$;
