CREATE OR REPLACE FUNCTION planning.get_workers(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE v_q text; v_active text; v_rows text[]; v_body text; r record;
BEGIN
  v_q := NULLIF(trim(COALESCE(p_params->>'q', '')), '');
  v_active := NULLIF(trim(COALESCE(p_params->>'active', '')), '');
  v_body := '<form><div class="grid">'
    || pgv.input('q', 'search', pgv.t('planning.filter_search_name'), v_q)
    || pgv.sel('active', pgv.t('planning.filter_status'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('planning.filter_all'), 'value', ''),
         jsonb_build_object('label', pgv.t('planning.filter_active'), 'value', 'true'),
         jsonb_build_object('label', pgv.t('planning.filter_inactive'), 'value', 'false')
       ), COALESCE(v_active, ''))
    || '</div><button type="submit" class="secondary">' || pgv.t('planning.btn_filter') || '</button></form>';
  v_rows := ARRAY[]::text[];
  FOR r IN
    SELECT w.id, w.name, w.role, w.phone, w.color, w.active,
           (SELECT count(*)::int FROM planning.assignment a JOIN planning.event e ON e.id = a.event_id WHERE a.worker_id = w.id AND e.end_date >= current_date) AS active_event_count
    FROM planning.worker w
    WHERE (v_q IS NULL OR w.name ILIKE '%' || v_q || '%' OR w.role ILIKE '%' || v_q || '%')
      AND (v_active IS NULL OR w.active = (v_active = 'true'))
    ORDER BY w.active DESC, w.name
  LOOP
    v_rows := v_rows || ARRAY[
      format('<a href="%s">%s</a>', pgv.call_ref('get_worker', jsonb_build_object('p_id', r.id)), pgv.esc(r.name)),
      COALESCE(r.role, '—'), COALESCE(r.phone, '—'),
      format('<span class="pgv-color-dot" style="background:%s"></span>', r.color),
      r.active_event_count::text,
      CASE WHEN r.active THEN pgv.badge(pgv.t('planning.status_active'), 'success') ELSE pgv.badge(pgv.t('planning.status_inactive'), 'default') END
    ];
  END LOOP;
  IF cardinality(v_rows) = 0 THEN
    v_body := v_body || pgv.empty(pgv.t('planning.empty_no_worker'), pgv.t('planning.empty_add_team'));
  ELSE
    v_body := v_body || pgv.md_table(ARRAY[pgv.t('planning.col_name'), pgv.t('planning.col_role'), pgv.t('planning.col_phone'), pgv.t('planning.col_color'), pgv.t('planning.col_active_events'), pgv.t('planning.col_status')], v_rows, 20);
  END IF;
  v_body := v_body || '<p>' || pgv.form_dialog('dlg-new-worker', pgv.t('planning.btn_new_worker'), planning._worker_form_inputs(), 'post_worker_save') || '</p>';
  RETURN v_body;
END;
$function$;
