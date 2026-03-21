CREATE OR REPLACE FUNCTION document.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('document.nav_documents'), 'icon', 'file-text'),
    jsonb_build_object('href', '/chartes', 'label', pgv.t('document.nav_chartes'), 'icon', 'palette')
  );
$function$;
