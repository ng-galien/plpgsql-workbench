CREATE OR REPLACE FUNCTION workbench.get_issue(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_iss    record;
  v_html   text;
  v_ctx    text;
BEGIN
  SELECT * INTO v_iss FROM workbench.issue_report WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN pgv.empty('Issue introuvable');
  END IF;

  v_html := pgv.breadcrumb(VARIADIC ARRAY[pgv.t('workbench.nav_issues'), pgv.call_ref('get_issues'), '#' || p_id::text]);

  v_html := v_html || pgv.grid(
    pgv.stat('Type', pgv.badge(v_iss.issue_type, CASE v_iss.issue_type WHEN 'bug' THEN 'danger' WHEN 'enhancement' THEN 'info' ELSE 'muted' END)),
    pgv.stat('Statut', pgv.badge(v_iss.status, CASE v_iss.status WHEN 'open' THEN 'warning' WHEN 'acknowledged' THEN 'info' WHEN 'resolved' THEN 'success' ELSE 'muted' END)),
    pgv.stat('Module', coalesce(v_iss.module, '-')),
    pgv.stat('Date', to_char(v_iss.created_at, 'DD/MM/YYYY HH24:MI'))
  );

  -- Description
  v_html := v_html || '<h4>Description</h4><md>' || E'\n' || pgv.md_esc(v_iss.description) || E'\n</md>';

  -- Context (if valid jsonb object, not garbage like "[object Object]")
  IF v_iss.context IS NOT NULL
     AND v_iss.context <> '{}'::jsonb
     AND jsonb_typeof(v_iss.context) = 'object'
  THEN
    v_ctx := workbench.format_jsonb(v_iss.context);
    IF v_ctx IS NOT NULL THEN
      v_html := v_html || '<h4>Contexte</h4>' || v_ctx;
    END IF;
  END IF;

  -- Message de dispatch lié
  IF v_iss.message_id IS NOT NULL THEN
    v_html := v_html || '<h4>Message de dispatch</h4>';
    v_html := v_html || '<md>' || E'\n';
    v_html := v_html || '| # | De | A | Type | Sujet | Statut |' || E'\n';
    v_html := v_html || '|---|----|----|------|-------|--------|' || E'\n';

    SELECT v_html || coalesce(
      '| [' || m.id || '](' || pgv.call_ref('get_message', jsonb_build_object('p_id', m.id)) || ')'
      || ' | ' || pgv.md_esc(m.from_module)
      || ' | ' || pgv.md_esc(m.to_module)
      || ' | ' || pgv.badge(m.msg_type, CASE m.msg_type WHEN 'task' THEN 'info' WHEN 'bug_report' THEN 'danger' ELSE 'muted' END)
      || ' | ' || pgv.md_esc(m.subject, 60)
      || ' | ' || pgv.badge(m.status, CASE m.status WHEN 'new' THEN 'warning' WHEN 'acknowledged' THEN 'info' WHEN 'resolved' THEN 'success' ELSE 'muted' END)
      || ' |', '') || E'\n</md>'
    INTO v_html
    FROM workbench.agent_message m
    WHERE m.id = v_iss.message_id;
  END IF;

  -- Autres messages référençant cette issue via payload
  v_html := v_html || '<h4>Messages lies</h4>';
  v_html := v_html || '<md>' || E'\n';
  v_html := v_html || '| # | De | A | Type | Sujet | Statut |' || E'\n';
  v_html := v_html || '|---|----|----|------|-------|--------|' || E'\n';

  SELECT v_html || coalesce(string_agg(
    '| [' || m.id || '](' || pgv.call_ref('get_message', jsonb_build_object('p_id', m.id)) || ')'
    || ' | ' || pgv.md_esc(m.from_module)
    || ' | ' || pgv.md_esc(m.to_module)
    || ' | ' || pgv.badge(m.msg_type, CASE m.msg_type WHEN 'task' THEN 'info' WHEN 'bug_report' THEN 'danger' ELSE 'muted' END)
    || ' | ' || pgv.md_esc(m.subject, 60)
    || ' | ' || pgv.badge(m.status, CASE m.status WHEN 'new' THEN 'warning' WHEN 'acknowledged' THEN 'info' WHEN 'resolved' THEN 'success' ELSE 'muted' END)
    || ' |', E'\n'
    ORDER BY m.id
  ), pgv.t('workbench.label_no_messages')) || E'\n</md>'
  INTO v_html
  FROM workbench.agent_message m
  WHERE (m.payload->>'issue_id')::integer = p_id
    AND m.id IS DISTINCT FROM v_iss.message_id;

  RETURN v_html;
END;
$function$;
