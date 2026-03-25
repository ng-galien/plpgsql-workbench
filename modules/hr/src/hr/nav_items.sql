CREATE OR REPLACE FUNCTION hr.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('hr.nav_salaries'), 'icon', 'users', 'entity', 'employee', 'uri', 'hr://employee'),
    jsonb_build_object('href', '/absences', 'label', pgv.t('hr.nav_absences'), 'icon', 'calendar', 'entity', 'absence', 'uri', 'hr://absence'),
    jsonb_build_object('href', '/timesheet', 'label', pgv.t('hr.nav_heures'), 'icon', 'clock', 'entity', 'timesheet', 'uri', 'hr://timesheet'),
    jsonb_build_object('href', '/registre', 'label', pgv.t('hr.nav_registre'), 'icon', 'book')
  );
$function$;
