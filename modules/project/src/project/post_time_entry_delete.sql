CREATE OR REPLACE FUNCTION project.post_time_entry_delete(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_pid int;
BEGIN
  SELECT t.project_id INTO v_pid FROM project.time_entry t JOIN project.project p ON p.id = t.project_id
  WHERE t.id = p_id AND p.status IN ('draft','active') AND p.tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('project.err_time_entry_not_editable'); END IF;
  DELETE FROM project.time_entry WHERE id = p_id;
  RETURN pgv.toast(pgv.t('project.toast_time_entry_deleted')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', v_pid)));
END;
$function$;
