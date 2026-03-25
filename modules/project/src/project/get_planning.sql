CREATE OR REPLACE FUNCTION project.get_planning()
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE v_body text; v_rows text[]; r record; v_tl_items jsonb;
BEGIN
  v_body := '<h3>' || pgv.t('project.title_planning') || '</h3>';
  v_rows := ARRAY[]::text[];
  FOR r IN SELECT p.id, p.code, cl.name AS client, p.subject,
      project._status_badge(p.status) AS status_badge, project._global_progress(p.id) AS pct,
      p.start_date, p.due_date,
      (SELECT count(*)::int FROM project.assignment a WHERE a.project_id = p.id) AS nb_workers
    FROM project.project p JOIN crm.client cl ON cl.id = p.client_id
    WHERE p.status IN ('draft','active','review') ORDER BY p.start_date NULLS LAST, p.code
  LOOP
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'date', COALESCE(to_char(m.planned_date, 'DD/MM/YYYY'), '—'), 'label', m.label,
      'detail', m.progress_pct || ' %',
      'badge', CASE m.status WHEN 'done' THEN 'success' WHEN 'in_progress' THEN 'info' ELSE 'default' END
    ) ORDER BY m.sort_order), '[]'::jsonb) INTO v_tl_items FROM project.milestone m WHERE m.project_id = r.id;
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_project', jsonb_build_object('p_id', r.id)), pgv.esc(r.code)),
      pgv.esc(r.client), r.status_badge, pgv.progress(r.pct, 100),
      COALESCE(to_char(r.start_date, 'DD/MM'), '—') || ' -> ' || COALESCE(to_char(r.due_date, 'DD/MM'), '—'),
      r.nb_workers::text,
      CASE WHEN v_tl_items = '[]'::jsonb THEN '—' ELSE pgv.timeline(v_tl_items) END];
  END LOOP;
  IF array_length(v_rows, 1) IS NULL THEN
    v_body := v_body || pgv.empty(pgv.t('project.empty_none_active'));
  ELSE
    v_body := v_body || pgv.md_table(
      ARRAY[pgv.t('project.col_project'), pgv.t('project.col_client'), pgv.t('project.col_status'), pgv.t('project.col_progress'), pgv.t('project.col_period'), pgv.t('project.col_team'), pgv.t('project.col_milestones')], v_rows);
  END IF;
  RETURN v_body;
END;
$function$;
