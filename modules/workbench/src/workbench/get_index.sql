CREATE OR REPLACE FUNCTION workbench.get_index()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_new_msg   integer;
  v_pending   integer;
  v_open_iss  integer;
  v_tools     integer;
  v_html      text;
BEGIN
  SELECT count(*) INTO v_new_msg
    FROM workbench.agent_message WHERE status = 'new';
  SELECT count(*) INTO v_pending
    FROM workbench.agent_message WHERE status = 'acknowledged';
  SELECT count(*) INTO v_open_iss
    FROM workbench.issue_report WHERE status IN ('open','acknowledged');
  SELECT count(*) INTO v_tools
    FROM workbench.toolbox_tool;

  v_html := pgv.grid(
    pgv.stat(pgv.t('workbench.stat_new_msg'), v_new_msg::text),
    pgv.stat(pgv.t('workbench.stat_pending'), v_pending::text),
    pgv.stat(pgv.t('workbench.stat_issues'), v_open_iss::text),
    pgv.stat(pgv.t('workbench.stat_tools'), v_tools::text)
  );

  v_html := v_html || '<h3>' || pgv.t('workbench.title_recent_msg') || '</h3>';
  v_html := v_html || '<md data-page="10">' || E'\n';
  v_html := v_html || '| # | De | A | Type | Sujet | Statut |' || E'\n';
  v_html := v_html || '|---|----|----|------|-------|--------|' || E'\n';

  SELECT v_html || coalesce(string_agg(
    '| [' || m.id || '](' || pgv.call_ref('get_message', jsonb_build_object('p_id', m.id)) || ') '
    || '| ' || m.from_module
    || ' | ' || CASE WHEN m.to_module = 'owner' THEN pgv.badge('owner', 'primary') ELSE m.to_module END
    || ' | ' || pgv.badge(m.msg_type, CASE m.msg_type
        WHEN 'task' THEN 'info'
        WHEN 'bug_report' THEN 'danger'
        WHEN 'feature_request' THEN 'warning'
        WHEN 'info' THEN 'muted'
        ELSE 'muted' END)
    || ' | ' || pgv.md_esc(m.subject, 60)
    || ' | ' || pgv.badge(m.status, CASE m.status
        WHEN 'new' THEN 'warning'
        WHEN 'acknowledged' THEN 'info'
        WHEN 'resolved' THEN 'success'
        ELSE 'muted' END)
    || ' |', E'\n'
    ORDER BY
      CASE WHEN m.to_module = 'owner' AND m.status <> 'resolved' THEN 0 ELSE 1 END,
      m.id DESC
  ), '') || E'\n</md>'
  INTO v_html
  FROM workbench.agent_message m;

  RETURN v_html;
END;
$function$;
