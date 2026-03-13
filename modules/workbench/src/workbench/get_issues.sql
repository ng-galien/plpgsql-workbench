CREATE OR REPLACE FUNCTION workbench.get_issues()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_open    integer;
  v_ack     integer;
  v_closed  integer;
  v_html    text;
BEGIN
  SELECT count(*) FILTER (WHERE status = 'open'),
         count(*) FILTER (WHERE status = 'acknowledged'),
         count(*) FILTER (WHERE status IN ('resolved','closed'))
    INTO v_open, v_ack, v_closed
    FROM workbench.issue_report;

  v_html := pgv.grid(
    pgv.stat('Ouvertes', v_open::text),
    pgv.stat('En cours', v_ack::text),
    pgv.stat('Resolues', v_closed::text)
  );

  v_html := v_html || '<md data-page="20">' || E'\n';
  v_html := v_html || '| # | Type | Module | Description | Statut | Date |' || E'\n';
  v_html := v_html || '|---|------|--------|-------------|--------|------|' || E'\n';

  SELECT v_html || coalesce(string_agg(
    '| ' || i.id
    || ' | ' || pgv.badge(i.issue_type, CASE i.issue_type WHEN 'bug' THEN 'danger' WHEN 'enhancement' THEN 'info' ELSE 'muted' END)
    || ' | ' || coalesce(i.module, '-')
    || ' | ' || pgv.md_esc(i.description)
    || ' | ' || pgv.badge(i.status, CASE i.status WHEN 'open' THEN 'warning' WHEN 'acknowledged' THEN 'info' WHEN 'resolved' THEN 'success' ELSE 'muted' END)
    || ' | ' || to_char(i.created_at, 'DD/MM HH24:MI')
    || ' |', E'\n'
    ORDER BY i.id DESC
  ), pgv.t('workbench.label_no_issues')) || E'\n</md>'
  INTO v_html
  FROM workbench.issue_report i;

  RETURN v_html;
END;
$function$;
