CREATE OR REPLACE FUNCTION planning.post_unassign(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_id int := (p_data->>'p_id')::int; v_event_id int := (p_data->>'p_event_id')::int;
BEGIN
  DELETE FROM planning.assignment WHERE id = v_id;
  IF NOT FOUND THEN RETURN pgv.toast(pgv.t('planning.toast_assignment_not_found'), 'error'); END IF;
  RETURN pgv.toast(pgv.t('planning.toast_unassigned')) || pgv.redirect(pgv.call_ref('get_event', jsonb_build_object('p_id', v_event_id)));
END;
$function$;
