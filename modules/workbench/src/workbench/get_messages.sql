CREATE OR REPLACE FUNCTION workbench.get_messages(p_module text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_total   integer;
  v_new     integer;
  v_ack     integer;
  v_resolved integer;
  v_html    text;
BEGIN
  SELECT count(*),
         count(*) FILTER (WHERE status = 'new'),
         count(*) FILTER (WHERE status = 'acknowledged'),
         count(*) FILTER (WHERE status = 'resolved')
    INTO v_total, v_new, v_ack, v_resolved
    FROM workbench.agent_message
   WHERE p_module IS NULL
      OR from_module = p_module
      OR to_module = p_module;

  v_html := pgv.grid(
    pgv.stat('Total', v_total::text),
    pgv.stat('Nouveaux', v_new::text),
    pgv.stat('En cours', v_ack::text),
    pgv.stat('Resolus', v_resolved::text)
  );

  v_html := v_html || '<md data-page="20">' || E'\n';
  v_html := v_html || '| # | De | A | Type | Priorite | Sujet | Statut | Date |' || E'\n';
  v_html := v_html || '|---|----|----|------|----------|-------|--------|------|' || E'\n';

  SELECT v_html || coalesce(string_agg(
    '| <button type="button" data-form-dialog="msg-detail" data-src="/message?p_id=' || m.id || '" class="outline pgv-btn-sm">' || m.id || '</button>'
    || ' | ' || m.from_module
    || ' | ' || m.to_module
    || ' | ' || pgv.badge(m.msg_type, CASE m.msg_type
        WHEN 'task' THEN 'info'
        WHEN 'bug_report' THEN 'danger'
        WHEN 'feature_request' THEN 'warning'
        WHEN 'breaking_change' THEN 'danger'
        WHEN 'info' THEN 'muted'
        ELSE 'muted' END)
    || ' | ' || CASE WHEN m.priority = 'high' THEN pgv.badge('HIGH','danger') ELSE 'normal' END
    || ' | ' || pgv.md_esc(m.subject, 60)
    || ' | ' || pgv.badge(m.status, CASE m.status
        WHEN 'new' THEN 'warning'
        WHEN 'acknowledged' THEN 'info'
        WHEN 'resolved' THEN 'success'
        ELSE 'muted' END)
    || ' | ' || to_char(m.created_at, 'DD/MM HH24:MI')
    || ' |', E'\n'
    ORDER BY m.id DESC
  ), '') || E'\n</md>'
    || '<dialog id="msg-detail" class="pgv-form-dialog"><article class="pgv-form-dialog-article">'
    || '<header class="pgv-form-dialog-header"><strong>' || pgv.t('workbench.title_message_detail') || '</strong>'
    || '<button class="pgv-form-dialog-close" onclick="this.closest(''dialog'').close()">&times;</button></header>'
    || '<div class="pgv-form-dialog-body"></div>'
    || '</article></dialog>'
  INTO v_html
  FROM workbench.agent_message m
  WHERE p_module IS NULL
     OR m.from_module = p_module
     OR m.to_module = p_module;

  RETURN v_html;
END;
$function$;
