CREATE OR REPLACE FUNCTION planning.post_assign(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_event_id int := (p_data->>'p_event_id')::int; v_worker_id int := (p_data->>'p_worker_id')::int;
BEGIN
  INSERT INTO planning.assignment (event_id, worker_id) VALUES (v_event_id, v_worker_id) ON CONFLICT (event_id, worker_id) DO NOTHING;
  RETURN pgv.toast(pgv.t('planning.toast_assigned')) || pgv.redirect(pgv.call_ref('get_event', jsonb_build_object('p_id', v_event_id)));
END;
$function$;
