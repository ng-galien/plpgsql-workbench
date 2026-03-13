CREATE OR REPLACE FUNCTION expense.nav_items()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('expense.nav_dashboard'), 'icon', 'home'),
    jsonb_build_object('href', '/notes', 'label', pgv.t('expense.nav_notes'), 'icon', 'file-text'),
    jsonb_build_object('href', '/categories', 'label', pgv.t('expense.nav_categories'), 'icon', 'tag')
  );
END;
$function$;
