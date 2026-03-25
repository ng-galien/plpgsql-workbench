CREATE OR REPLACE FUNCTION planning.get_event(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE v record; v_body text; v_rows text[]; r record; v_project_label text; v_worker_options text;
BEGIN
  SELECT e.*, p.code AS project_code INTO v FROM planning.event e LEFT JOIN project.project p ON p.id = e.project_id WHERE e.id = p_id;
  IF NOT FOUND THEN RETURN pgv.error('404', pgv.t('planning.err_event_not_found')); END IF;
  v_project_label := COALESCE(v.project_code, '—');
  v_body := pgv.dl(
    pgv.t('planning.field_title'), pgv.esc(v.title),
    pgv.t('planning.field_type'), planning._type_badge(v.type),
    pgv.t('planning.col_dates'), to_char(v.start_date, 'DD/MM/YYYY') || ' -> ' || to_char(v.end_date, 'DD/MM/YYYY'),
    pgv.t('planning.field_start_time') || ' – ' || pgv.t('planning.field_end_time'), to_char(v.start_time, 'HH24:MI') || ' – ' || to_char(v.end_time, 'HH24:MI'),
    pgv.t('planning.field_location'), COALESCE(NULLIF(v.location, ''), '—'),
    pgv.t('planning.col_project'), v_project_label,
    pgv.t('planning.field_notes'), COALESCE(NULLIF(v.notes, ''), '—')
  );
  v_rows := ARRAY[]::text[];
  FOR r IN SELECT w.id, w.name, w.role, a.id AS assignment_id FROM planning.assignment a JOIN planning.worker w ON w.id = a.worker_id WHERE a.event_id = p_id ORDER BY w.name
  LOOP
    v_rows := v_rows || ARRAY[format('<a href="%s">%s</a>', pgv.call_ref('get_worker', jsonb_build_object('p_id', r.id)), pgv.esc(r.name)), COALESCE(NULLIF(r.role, ''), '—'), pgv.action('post_unassign', pgv.t('planning.btn_remove'), jsonb_build_object('p_id', r.assignment_id, 'p_event_id', p_id), NULL, 'secondary')];
  END LOOP;
  v_body := v_body || '<h4>' || pgv.t('planning.title_assigned_team') || '</h4>';
  IF cardinality(v_rows) > 0 THEN
    v_body := v_body || pgv.md_table(ARRAY[pgv.t('planning.col_worker'), pgv.t('planning.col_role'), ''], v_rows);
  ELSE
    v_body := v_body || pgv.empty(pgv.t('planning.empty_no_assignment'));
  END IF;
  SELECT string_agg(format('<option value="%s">%s (%s)</option>', w.id, pgv.esc(w.name), pgv.esc(w.role)), '' ORDER BY w.name) INTO v_worker_options
  FROM planning.worker w WHERE w.active AND w.id NOT IN (SELECT a.worker_id FROM planning.assignment a WHERE a.event_id = p_id);
  IF v_worker_options IS NOT NULL THEN
    v_body := v_body || pgv.form('post_assign', format('<input type="hidden" name="p_event_id" value="%s">', p_id) || '<div class="grid"><label>' || pgv.t('planning.btn_add_worker') || '<select name="p_worker_id">' || v_worker_options || '</select></label></div>', pgv.t('planning.btn_assign'));
  END IF;
  v_body := v_body || '<p>' || pgv.form_dialog('dlg-edit-event', pgv.t('planning.btn_edit'), planning._event_form_inputs(v.id, v.title, v.type, v.start_date, v.end_date, v.start_time, v.end_time, v.location, v.project_id, v.notes), 'post_event_save') || ' ' || pgv.action('post_event_delete', pgv.t('planning.btn_delete'), jsonb_build_object('p_id', p_id), pgv.t('planning.confirm_delete_event'), 'error') || '</p>';
  RETURN v_body;
END;
$function$;
