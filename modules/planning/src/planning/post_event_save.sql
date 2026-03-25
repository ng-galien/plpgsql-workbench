CREATE OR REPLACE FUNCTION planning.post_event_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_id int := NULLIF(p_data->>'id', '')::int; v_title text := trim(p_data->>'title'); v_start date := (p_data->>'start_date')::date; v_end date := (p_data->>'end_date')::date;
BEGIN
  IF v_title IS NULL OR v_title = '' THEN RETURN pgv.toast(pgv.t('planning.err_title_required'), 'error'); END IF;
  IF v_end < v_start THEN RETURN pgv.toast(pgv.t('planning.err_date_order'), 'error'); END IF;
  IF v_id IS NOT NULL THEN
    UPDATE planning.event SET title = v_title, type = COALESCE(NULLIF(trim(p_data->>'type'), ''), type), start_date = v_start, end_date = v_end, start_time = COALESCE(NULLIF(trim(p_data->>'start_time'), '')::time, start_time), end_time = COALESCE(NULLIF(trim(p_data->>'end_time'), '')::time, end_time), location = COALESCE(trim(p_data->>'location'), location), project_id = NULLIF(trim(p_data->>'project_id'), '')::int, notes = COALESCE(trim(p_data->>'notes'), notes) WHERE id = v_id;
  ELSE
    INSERT INTO planning.event (title, type, start_date, end_date, start_time, end_time, location, project_id, notes) VALUES (v_title, COALESCE(NULLIF(trim(p_data->>'type'), ''), 'job_site'), v_start, v_end, COALESCE(NULLIF(trim(p_data->>'start_time'), '')::time, '08:00'), COALESCE(NULLIF(trim(p_data->>'end_time'), '')::time, '17:00'), COALESCE(trim(p_data->>'location'), ''), NULLIF(trim(p_data->>'project_id'), '')::int, COALESCE(trim(p_data->>'notes'), '')) RETURNING id INTO v_id;
  END IF;
  RETURN pgv.toast(pgv.t('planning.toast_event_saved')) || pgv.redirect(pgv.call_ref('get_event', jsonb_build_object('p_id', v_id)));
END;
$function$;
