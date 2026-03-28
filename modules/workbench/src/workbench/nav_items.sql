CREATE OR REPLACE FUNCTION workbench.nav_items()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
SELECT jsonb_build_array(
    jsonb_build_object('label', pgv.t('workbench.nav_messages'), 'icon', 'mail', 'uri', 'workbench://agent_message', 'entity', 'agent_message'),
    jsonb_build_object('label', pgv.t('workbench.nav_issues'),   'icon', 'alert-circle', 'uri', 'workbench://issue_report', 'entity', 'issue_report')
  );
$function$;
