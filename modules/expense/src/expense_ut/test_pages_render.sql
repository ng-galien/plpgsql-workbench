CREATE OR REPLACE FUNCTION expense_ut.test_pages_render()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  RETURN NEXT ok(expense.brand() IS NOT NULL, 'brand renders');
  RETURN NEXT ok(expense.nav_items() IS NOT NULL, 'nav_items renders');
  RETURN NEXT ok(expense.expense_report_view() IS NOT NULL, 'expense_report_view renders');
  RETURN NEXT ok(expense.category_view() IS NOT NULL, 'category_view renders');
END;
$function$;
