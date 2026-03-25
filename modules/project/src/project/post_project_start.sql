CREATE OR REPLACE FUNCTION project.post_project_start(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE project.project SET status = 'active', updated_at = now() WHERE id = p_id AND status = 'draft' AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('project.err_not_draft'); END IF;
  RETURN pgv.toast(pgv.t('project.toast_started')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', p_id)));
END;
$function$;
