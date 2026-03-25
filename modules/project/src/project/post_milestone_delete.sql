CREATE OR REPLACE FUNCTION project.post_milestone_delete(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_pid int;
BEGIN
  SELECT m.project_id INTO v_pid FROM project.milestone m JOIN project.project p ON p.id = m.project_id
  WHERE m.id = p_id AND p.status IN ('draft','active') AND p.tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('project.err_milestone_not_editable'); END IF;
  DELETE FROM project.milestone WHERE id = p_id;
  RETURN pgv.toast(pgv.t('project.toast_milestone_deleted')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', v_pid)));
END;
$function$;
