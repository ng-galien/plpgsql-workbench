CREATE OR REPLACE FUNCTION ops.nav_items()
 RETURNS jsonb
 LANGUAGE sql
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('ops.nav_agents'), 'icon', 'terminal'),
    jsonb_build_object('href', '/modules', 'label', pgv.t('ops.nav_modules'), 'icon', 'package'),
    jsonb_build_object('href', '/tests', 'label', pgv.t('ops.nav_tests'), 'icon', 'check-circle'),
    jsonb_build_object('href', '/dashboard', 'label', pgv.t('ops.nav_health'), 'icon', 'activity'),
    jsonb_build_object('href', '/hooks', 'label', pgv.t('ops.nav_hooks'), 'icon', 'shield'),
    jsonb_build_object('href', '/docs', 'label', pgv.t('ops.nav_docs'), 'icon', 'book-open')
  );
$function$;
