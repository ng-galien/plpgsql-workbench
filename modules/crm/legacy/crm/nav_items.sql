CREATE OR REPLACE FUNCTION crm.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('crm.nav_clients'), 'icon', 'users', 'entity', 'client'),
    jsonb_build_object('href', '/interactions', 'label', pgv.t('crm.nav_interactions'), 'icon', 'message-circle', 'entity', 'interaction'),
    jsonb_build_object('href', '/import', 'label', pgv.t('crm.nav_import'), 'icon', 'upload')
  );
$function$;
