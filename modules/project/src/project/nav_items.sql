CREATE OR REPLACE FUNCTION project.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('project.nav_dashboard'), 'icon', 'home'),
    jsonb_build_object('href', '/projects', 'label', pgv.t('project.nav_projects'), 'icon', 'briefcase', 'entity', 'project', 'uri', 'project://project'),
    jsonb_build_object('href', '/planning', 'label', pgv.t('project.nav_planning'), 'icon', 'calendar')
  );
$function$;
