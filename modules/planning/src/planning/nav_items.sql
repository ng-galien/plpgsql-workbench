CREATE OR REPLACE FUNCTION planning.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('href', '/', 'label', pgv.t('planning.nav_agenda'), 'icon', 'calendar'),
    jsonb_build_object('href', '/intervenants', 'label', pgv.t('planning.nav_equipe'), 'icon', 'users', 'entity', 'intervenant', 'uri', 'planning://intervenant'),
    jsonb_build_object('href', '/evenements', 'label', pgv.t('planning.nav_evenements'), 'icon', 'list', 'entity', 'evenement', 'uri', 'planning://evenement')
  );
$function$;
