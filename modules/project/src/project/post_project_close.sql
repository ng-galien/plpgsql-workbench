CREATE OR REPLACE FUNCTION project.post_project_close(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE project.project SET status = 'closed', end_date = CURRENT_DATE, updated_at = now() WHERE id = p_id AND status = 'review' AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('project.err_not_review'); END IF;
  RETURN pgv.toast(pgv.t('project.toast_closed')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', p_id)));
END;
$function$;
