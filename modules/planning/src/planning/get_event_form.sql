CREATE OR REPLACE FUNCTION planning.get_event_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE v planning.event; v_body text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v FROM planning.event WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.error('404', pgv.t('planning.err_event_not_found')); END IF;
  END IF;
  v_body := pgv.form('post_event_save', planning._event_form_inputs(p_id, v.title, v.type, v.start_date, v.end_date, v.start_time, v.end_time, v.location, v.project_id, v.notes), pgv.t('planning.btn_save'));
  RETURN v_body;
END;
$function$;
