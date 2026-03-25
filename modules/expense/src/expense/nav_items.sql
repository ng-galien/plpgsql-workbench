CREATE OR REPLACE FUNCTION expense.nav_items()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('expense.nav_dashboard'), 'icon', 'home'),
    jsonb_build_object('href', '/notes', 'label', pgv.t('expense.nav_notes'), 'icon', 'file-text', 'entity', 'note', 'uri', 'expense://note'),
    jsonb_build_object('href', '/categories', 'label', pgv.t('expense.nav_categories'), 'icon', 'tag', 'entity', 'categorie', 'uri', 'expense://categorie')
  );
END;
$function$;
