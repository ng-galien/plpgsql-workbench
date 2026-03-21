CREATE OR REPLACE FUNCTION docs.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('docs.nav_documents'), 'icon', 'file-text'),
    jsonb_build_object('href', '/chartes', 'label', pgv.t('docs.nav_chartes'), 'icon', 'palette'),
    jsonb_build_object('href', '/libraries', 'label', pgv.t('docs.nav_libraries'), 'icon', 'image')
  );
$function$;
