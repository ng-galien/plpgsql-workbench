CREATE OR REPLACE FUNCTION document.nav_items()
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('document.nav_documents'), 'icon', 'file-text'),
    jsonb_build_object('href', '/templates', 'label', pgv.t('document.nav_templates'), 'icon', 'layout'),
    jsonb_build_object('href', '/company', 'label', pgv.t('document.nav_company'), 'icon', 'building')
  );
END;
$function$;
