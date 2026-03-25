CREATE OR REPLACE FUNCTION planning.post_event_delete(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  DELETE FROM planning.event WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.toast(pgv.t('planning.err_event_not_found'), 'error'); END IF;
  RETURN pgv.toast(pgv.t('planning.toast_event_deleted')) || pgv.redirect(pgv.call_ref('get_events'));
END;
$function$;
