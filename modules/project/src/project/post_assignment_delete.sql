CREATE OR REPLACE FUNCTION project.post_assignment_delete(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_pid int;
BEGIN
  SELECT a.project_id INTO v_pid FROM project.assignment a JOIN project.project p ON p.id = a.project_id
  WHERE a.id = p_id AND p.tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('project.err_assignment_not_found'); END IF;
  DELETE FROM project.assignment WHERE id = p_id;
  RETURN pgv.toast(pgv.t('project.toast_assignment_deleted')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', v_pid)));
END;
$function$;
