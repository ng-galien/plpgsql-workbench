CREATE OR REPLACE FUNCTION workbench.get_message(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_msg    record;
  v_html   text;
  v_issue  record;
BEGIN
  SELECT * INTO v_msg FROM workbench.agent_message WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.empty(pgv.t('workbench.label_no_messages'));
  END IF;

  v_html := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('workbench.nav_messages'), pgv.call_ref('get_messages'), '#' || p_id::text]);

  v_html := v_html || pgv.grid(
    pgv.stat('Type', pgv.badge(v_msg.msg_type, CASE v_msg.msg_type
        WHEN 'task' THEN 'info'
        WHEN 'bug_report' THEN 'danger'
        WHEN 'feature_request' THEN 'warning'
        WHEN 'info' THEN 'muted'
        ELSE 'muted' END)),
    pgv.stat('Statut', pgv.badge(v_msg.status, CASE v_msg.status
        WHEN 'new' THEN 'warning'
        WHEN 'acknowledged' THEN 'info'
        WHEN 'resolved' THEN 'success'
        ELSE 'muted' END)),
    pgv.stat('Priorite', CASE WHEN v_msg.priority = 'high' THEN pgv.badge('HIGH','danger') ELSE 'normal' END),
    pgv.stat('Date', to_char(v_msg.created_at, 'DD/MM/YYYY HH24:MI'))
  );

  v_html := v_html || '<md>' || E'\n';
  v_html := v_html || '| Champ | Valeur |' || E'\n';
  v_html := v_html || '|-------|--------|' || E'\n';
  v_html := v_html || '| De | ' || pgv.md_esc(v_msg.from_module) || ' |' || E'\n';
  v_html := v_html || '| A | ' || pgv.md_esc(v_msg.to_module) || ' |' || E'\n';
  v_html := v_html || '| Sujet | ' || pgv.md_esc(v_msg.subject, 120) || ' |' || E'\n';
  IF v_msg.body IS NOT NULL THEN
    v_html := v_html || '| Corps | ' || pgv.md_esc(v_msg.body, 200) || ' |' || E'\n';
  END IF;
  IF v_msg.resolution IS NOT NULL THEN
    v_html := v_html || '| Resolution | ' || pgv.md_esc(v_msg.resolution, 200) || ' |' || E'\n';
  END IF;
  v_html := v_html || '</md>' || E'\n';

  SELECT * INTO v_issue FROM workbench.issue_report WHERE message_id = p_id;
  IF FOUND THEN
    v_html := v_html || '<h4>Issue liee #' || v_issue.id || '</h4>';
    v_html := v_html || '<md>' || E'\n';
    v_html := v_html || '| Champ | Valeur |' || E'\n';
    v_html := v_html || '|-------|--------|' || E'\n';
    v_html := v_html || '| Type | ' || pgv.badge(v_issue.issue_type, CASE v_issue.issue_type WHEN 'bug' THEN 'danger' ELSE 'info' END) || ' |' || E'\n';
    v_html := v_html || '| Module | ' || coalesce(v_issue.module, '-') || ' |' || E'\n';
    v_html := v_html || '| Statut | ' || pgv.badge(v_issue.status, CASE v_issue.status WHEN 'open' THEN 'warning' WHEN 'resolved' THEN 'success' ELSE 'info' END) || ' |' || E'\n';
    v_html := v_html || '| Description | ' || pgv.md_esc(v_issue.description, 200) || ' |' || E'\n';
    v_html := v_html || '</md>' || E'\n';
  END IF;

  v_html := v_html || '<h4>Fil de discussion</h4>';
  v_html := v_html || '<md>' || E'\n';
  v_html := v_html || '| # | De | A | Sujet | Statut | Date |' || E'\n';
  v_html := v_html || '|---|----|---|-------|--------|------|' || E'\n';

  SELECT v_html || coalesce(string_agg(
    '| [' || r.id || '](' || pgv.call_ref('get_message', jsonb_build_object('p_id', r.id)) || ')'
    || ' | ' || pgv.md_esc(r.from_module)
    || ' | ' || pgv.md_esc(r.to_module)
    || ' | ' || pgv.md_esc(r.subject)
    || ' | ' || pgv.badge(r.status, CASE r.status
        WHEN 'new' THEN 'warning'
        WHEN 'acknowledged' THEN 'info'
        WHEN 'resolved' THEN 'success'
        ELSE 'muted' END)
    || ' | ' || to_char(r.created_at, 'DD/MM HH24:MI')
    || ' |', E'\n'
    ORDER BY r.id
  ), '') || E'\n</md>'
  INTO v_html
  FROM workbench.agent_message r
  WHERE r.reply_to = p_id OR r.id = p_id;

  IF v_msg.payload IS NOT NULL THEN
    v_html := v_html || '<h4>Payload</h4><pre>' || jsonb_pretty(v_msg.payload) || '</pre>';
  END IF;
  IF v_msg.result IS NOT NULL THEN
    v_html := v_html || '<h4>Result</h4><pre>' || jsonb_pretty(v_msg.result) || '</pre>';
  END IF;

  RETURN v_html;
END;
$function$;
