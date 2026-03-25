CREATE OR REPLACE FUNCTION planning.get_worker(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE v record; v_body text; v_rows text[]; r record;
BEGIN
  SELECT * INTO v FROM planning.worker WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.error('404', pgv.t('planning.err_worker_not_found')); END IF;
  v_body := pgv.dl(
    pgv.t('planning.field_name'), pgv.esc(v.name),
    pgv.t('planning.field_role'), COALESCE(NULLIF(v.role, ''), '—'),
    pgv.t('planning.field_phone'), COALESCE(v.phone, '—'),
    pgv.t('planning.field_color'), format('<span class="pgv-color-dot" style="background:%s"></span> %s', v.color, v.color),
    pgv.t('planning.col_status'), CASE WHEN v.active THEN pgv.badge(pgv.t('planning.status_active'), 'success') ELSE pgv.badge(pgv.t('planning.status_inactive'), 'default') END,
    pgv.t('planning.field_created_at'), to_char(v.created_at, 'DD/MM/YYYY')
  );
  v_rows := ARRAY[]::text[];
  FOR r IN SELECT e.id, e.title, e.type, e.start_date, e.end_date, e.location FROM planning.event e JOIN planning.assignment a ON a.event_id = e.id WHERE a.worker_id = p_id AND e.end_date >= current_date ORDER BY e.start_date
  LOOP
    v_rows := v_rows || ARRAY[format('<a href="%s">%s</a>', pgv.call_ref('get_event', jsonb_build_object('p_id', r.id)), pgv.esc(r.title)), planning._type_badge(r.type), to_char(r.start_date, 'DD/MM') || ' -> ' || to_char(r.end_date, 'DD/MM'), COALESCE(NULLIF(r.location, ''), '—')];
  END LOOP;
  IF cardinality(v_rows) > 0 THEN
    v_body := v_body || '<h4>' || pgv.t('planning.title_upcoming_events') || '</h4>' || pgv.md_table(ARRAY[pgv.t('planning.col_event'), pgv.t('planning.col_type'), pgv.t('planning.col_dates'), pgv.t('planning.col_location')], v_rows);
  ELSE
    v_body := v_body || pgv.empty(pgv.t('planning.empty_no_upcoming_event'));
  END IF;
  v_body := v_body || '<p>' || pgv.form_dialog('dlg-edit-worker', pgv.t('planning.btn_edit'), planning._worker_form_inputs(v.id, v.name, v.role, v.phone, v.color, v.active), 'post_worker_save') || ' ' || pgv.action('post_worker_delete', pgv.t('planning.btn_delete'), jsonb_build_object('p_id', p_id), pgv.t('planning.confirm_delete_worker'), 'error') || '</p>';
  RETURN v_body;
END;
$function$;
