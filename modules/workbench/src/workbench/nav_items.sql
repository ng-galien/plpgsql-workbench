CREATE OR REPLACE FUNCTION workbench.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
  SELECT jsonb_build_array(
    jsonb_build_object('label', pgv.t('workbench.nav_messages'), 'href', pgv.call_ref('get_messages')),
    jsonb_build_object('label', pgv.t('workbench.nav_issues'),   'href', pgv.call_ref('get_issues')),
    jsonb_build_object('label', pgv.t('workbench.nav_tools'),    'href', pgv.call_ref('get_tools')),
    jsonb_build_object('label', 'Primitives',                    'href', pgv.call_ref('get_primitives'))
  );
$function$;
