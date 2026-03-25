CREATE OR REPLACE FUNCTION planning.get_index(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE v_date date; v_monday date; v_body text; v_total_workers int; v_total_events_week int; v_total_assignments_week int; v_day date; v_rows text[]; r record; v_evts text;
BEGIN
  v_date := COALESCE((p_params->>'date')::date, current_date);
  v_monday := v_date - extract(isodow FROM v_date)::int + 1;
  SELECT count(*)::int INTO v_total_workers FROM planning.worker WHERE active;
  SELECT count(*)::int INTO v_total_events_week FROM planning.event WHERE start_date <= v_monday + 6 AND end_date >= v_monday;
  SELECT count(*)::int INTO v_total_assignments_week FROM planning.assignment a JOIN planning.event e ON e.id = a.event_id WHERE e.start_date <= v_monday + 6 AND e.end_date >= v_monday;
  v_body := pgv.grid(VARIADIC ARRAY[pgv.stat(pgv.t('planning.stat_workers'), v_total_workers::text), pgv.stat(pgv.t('planning.stat_events_week'), v_total_events_week::text), pgv.stat(pgv.t('planning.stat_assignments_week'), v_total_assignments_week::text)]);
  v_body := v_body || '<nav class="pgv-week-nav">' || pgv.link_button(pgv.call_ref('get_index', jsonb_build_object('date', (v_monday - 7)::text)), '&larr;', 'outline') || ' <strong>' || pgv.t('planning.title_week_of') || ' ' || to_char(v_monday, 'DD/MM') || ' au ' || to_char(v_monday + 6, 'DD/MM/YYYY') || '</strong> ' || pgv.link_button(pgv.call_ref('get_index', jsonb_build_object('date', (v_monday + 7)::text)), '&rarr;', 'outline') || '</nav>';
  v_rows := ARRAY[]::text[];
  FOR r IN SELECT w.id, w.name, w.role, w.color FROM planning.worker w WHERE w.active ORDER BY w.name
  LOOP
    v_rows := v_rows || ARRAY[format('<strong>%s</strong><br><small>%s</small>', pgv.esc(r.name), pgv.esc(r.role))];
    FOR d IN 0..6 LOOP
      v_day := v_monday + d;
      SELECT string_agg(format('<a href="%s" class="pgv-event-chip" style="border-left:3px solid %s">%s</a>', pgv.call_ref('get_event', jsonb_build_object('p_id', e.id)), r.color, pgv.esc(CASE WHEN length(e.title) > 15 THEN left(e.title, 12) || '...' ELSE e.title END)), '' ORDER BY e.start_time) INTO v_evts
      FROM planning.event e JOIN planning.assignment af ON af.event_id = e.id WHERE af.worker_id = r.id AND e.start_date <= v_day AND e.end_date >= v_day;
      v_rows := v_rows || ARRAY[COALESCE(v_evts, '')];
    END LOOP;
  END LOOP;
  IF v_total_workers = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('planning.empty_no_worker'), pgv.t('planning.empty_first_worker'));
  ELSE
    v_body := v_body || pgv.md_table(ARRAY[pgv.t('planning.col_worker'), to_char(v_monday, 'Dy DD'), to_char(v_monday+1, 'Dy DD'), to_char(v_monday+2, 'Dy DD'), to_char(v_monday+3, 'Dy DD'), to_char(v_monday+4, 'Dy DD'), to_char(v_monday+5, 'Dy DD'), to_char(v_monday+6, 'Dy DD')], v_rows);
  END IF;
  v_body := v_body || '<p>' || pgv.form_dialog('dlg-new-event', pgv.t('planning.btn_new_event'), planning._event_form_inputs(), 'post_event_save') || ' ' || pgv.link_button(pgv.call_ref('get_workers'), pgv.t('planning.btn_manage_team'), 'secondary') || '</p>';
  RETURN v_body;
END;
$function$;
