CREATE OR REPLACE FUNCTION planning.get_events(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE v_q text; v_type text; v_from date; v_rows text[]; v_body text; r record;
BEGIN
  v_q := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_type := NULLIF(trim(COALESCE(p_params->>'type', '')), '');
  v_from := COALESCE(NULLIF(trim(COALESCE(p_params->>'from', '')), '')::date, current_date - 30);
  v_body := '<form><div class="grid">'
    || pgv.input('q', 'search', pgv.t('planning.filter_search_title'), v_q)
    || pgv.sel('type', pgv.t('planning.field_type'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('planning.filter_all'), 'value', ''),
         jsonb_build_object('label', pgv.t('planning.type_job_site'), 'value', 'job_site'),
         jsonb_build_object('label', pgv.t('planning.type_delivery'), 'value', 'delivery'),
         jsonb_build_object('label', pgv.t('planning.type_meeting'), 'value', 'meeting'),
         jsonb_build_object('label', pgv.t('planning.type_leave'), 'value', 'leave'),
         jsonb_build_object('label', pgv.t('planning.type_other'), 'value', 'other')
       ), COALESCE(v_type, ''))
    || pgv.input('from', 'date', pgv.t('planning.filter_from_date'), v_from::text)
    || '</div><button type="submit" class="secondary">' || pgv.t('planning.btn_filter') || '</button></form>';
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT e.id, e.title, e.type, e.start_date, e.end_date, e.location,
           (SELECT string_agg(w.name, ', ' ORDER BY w.name) FROM planning.assignment a JOIN planning.worker w ON w.id = a.worker_id WHERE a.event_id = e.id) AS workers,
           p.code AS project_code
    FROM planning.event e LEFT JOIN project.project p ON p.id = e.project_id
    WHERE e.end_date >= v_from AND (v_q IS NULL OR e.title ILIKE '%' || v_q || '%' OR e.location ILIKE '%' || v_q || '%') AND (v_type IS NULL OR e.type = v_type)
    ORDER BY e.start_date DESC
  LOOP
    v_rows := v_rows || ARRAY[format('<a href="%s">%s</a>', pgv.call_ref('get_event', jsonb_build_object('p_id', r.id)), pgv.esc(r.title)), planning._type_badge(r.type), to_char(r.start_date, 'DD/MM') || ' -> ' || to_char(r.end_date, 'DD/MM'), COALESCE(NULLIF(r.location, ''), '—'), COALESCE(r.workers, '—'), COALESCE(r.project_code, '—')];
  END LOOP;
  IF cardinality(v_rows) = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('planning.empty_no_event'));
  ELSE
    v_body := v_body || pgv.md_table(ARRAY[pgv.t('planning.col_event'), pgv.t('planning.col_type'), pgv.t('planning.col_dates'), pgv.t('planning.col_location'), pgv.t('planning.col_workers'), pgv.t('planning.col_project')], v_rows, 20);
  END IF;
  v_body := v_body || '<p>' || pgv.form_dialog('dlg-new-event', pgv.t('planning.btn_new_event'), planning._event_form_inputs(), 'post_event_save') || '</p>';
  RETURN v_body;
END;
$function$;
