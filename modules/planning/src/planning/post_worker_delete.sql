CREATE OR REPLACE FUNCTION planning.post_worker_delete(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  DELETE FROM planning.worker WHERE id = p_id;
  IF NOT FOUND THEN RETURN pgv.toast(pgv.t('planning.err_worker_not_found'), 'error'); END IF;
  RETURN pgv.toast(pgv.t('planning.toast_worker_deleted')) || pgv.redirect(pgv.call_ref('get_workers'));
END;
$function$;
