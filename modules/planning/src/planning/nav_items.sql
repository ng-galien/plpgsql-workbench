CREATE OR REPLACE FUNCTION planning.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
SELECT jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('planning.nav_agenda'), 'icon', 'calendar'),
    jsonb_build_object('href', '/workers', 'label', pgv.t('planning.nav_team'), 'icon', 'users', 'entity', 'worker', 'uri', 'planning://worker'),
    jsonb_build_object('href', '/events', 'label', pgv.t('planning.nav_events'), 'icon', 'list', 'entity', 'event', 'uri', 'planning://event')
  )
$function$;
