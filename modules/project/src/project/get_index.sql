CREATE OR REPLACE FUNCTION project.get_index()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE v_active int; v_draft int; v_closed_month int; v_hours_week numeric;
  v_body text; v_rows text[]; v_alert_rows text[]; r record;
BEGIN
  SELECT count(*)::int INTO v_active FROM project.project WHERE status = 'active';
  SELECT count(*)::int INTO v_draft FROM project.project WHERE status = 'draft';
  SELECT count(*)::int INTO v_closed_month FROM project.project WHERE status = 'closed' AND end_date >= date_trunc('month', CURRENT_DATE);
  SELECT COALESCE(sum(hours), 0) INTO v_hours_week FROM project.time_entry WHERE entry_date >= date_trunc('week', CURRENT_DATE);
  v_body := pgv.grid(VARIADIC ARRAY[
    pgv.stat(pgv.t('project.stat_active'), v_active::text),
    pgv.stat(pgv.t('project.stat_draft'), v_draft::text),
    pgv.stat(pgv.t('project.stat_closed_month'), v_closed_month::text),
    pgv.stat(pgv.t('project.stat_hours_week'), v_hours_week::text || ' h')]);
  v_alert_rows := ARRAY[]::text[];
  FOR r IN SELECT p.id, p.code, cl.name AS client, p.subject, project._status_badge(p.status) AS badge, (CURRENT_DATE - p.due_date) AS days_late
    FROM project.project p JOIN crm.client cl ON cl.id = p.client_id WHERE p.due_date < CURRENT_DATE AND p.status NOT IN ('closed','review') ORDER BY p.due_date
  LOOP
    v_alert_rows := v_alert_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_project', jsonb_build_object('p_id', r.id)), pgv.esc(r.code)),
      pgv.esc(r.client), pgv.esc(r.subject), r.badge, pgv.badge(r.days_late::text || ' d', 'warning')];
  END LOOP;
  IF array_length(v_alert_rows, 1) IS NOT NULL THEN
    v_body := v_body || '<h3>' || pgv.t('project.title_late_alerts') || '</h3>'
      || pgv.md_table(ARRAY[pgv.t('project.col_code'), pgv.t('project.col_client'), pgv.t('project.col_subject'), pgv.t('project.col_status'), pgv.t('project.col_late')], v_alert_rows);
  END IF;
  v_rows := ARRAY[]::text[];
  FOR r IN SELECT p.id, p.client_id, p.code, cl.name AS client, p.subject, p.status,
      project._global_progress(p.id) AS pct, p.start_date
    FROM project.project p JOIN crm.client cl ON cl.id = p.client_id
    WHERE p.status IN ('draft','active','review') ORDER BY p.updated_at DESC LIMIT 20
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_project', jsonb_build_object('p_id', r.id)), pgv.esc(r.code)),
      format('<a href="/crm/client?p_id=%s">%s</a>', r.client_id, pgv.esc(r.client)),
      pgv.esc(r.subject), project._status_badge(r.status), pgv.badge(r.pct::text || ' %'),
      COALESCE(to_char(r.start_date, 'DD/MM/YYYY'), '—')];
  END LOOP;
  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('project.empty_none_active'), pgv.t('project.empty_create_first'));
  ELSE
    v_body := v_body || '<h3>' || pgv.t('project.title_active_projects') || '</h3>'
      || pgv.md_table(ARRAY[pgv.t('project.col_code'), pgv.t('project.col_client'), pgv.t('project.col_subject'), pgv.t('project.col_status'), pgv.t('project.col_progress'), pgv.t('project.col_start')], v_rows, 10);
  END IF;
  v_body := v_body || '<p>' || pgv.form_dialog('dlg-new-project', pgv.t('project.btn_new'), project._project_form_fields(), 'post_project_save') || '</p>';
  RETURN v_body;
END;
$function$;
