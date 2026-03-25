CREATE OR REPLACE FUNCTION project.post_project_delete(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  DELETE FROM project.project WHERE id = p_id AND status = 'draft' AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('project.err_not_draft'); END IF;
  RETURN pgv.toast(pgv.t('project.toast_deleted')) || pgv.redirect(pgv.call_ref('get_projects'));
END;
$function$;
