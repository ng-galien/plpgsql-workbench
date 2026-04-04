CREATE OR REPLACE FUNCTION expense.nav_items()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('expense.nav_dashboard'), 'icon', 'home'),
    jsonb_build_object('href', '/expense_reports', 'label', pgv.t('expense.nav_reports'), 'icon', 'file-text', 'entity', 'expense_report', 'uri', 'expense://expense_report'),
    jsonb_build_object('href', '/categories', 'label', pgv.t('expense.nav_categories'), 'icon', 'tag', 'entity', 'category', 'uri', 'expense://category')
  );
END;
$function$;
