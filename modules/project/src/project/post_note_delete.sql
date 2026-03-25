CREATE OR REPLACE FUNCTION project.post_note_delete(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_pid int;
BEGIN
  SELECT n.project_id INTO v_pid FROM project.project_note n JOIN project.project p ON p.id = n.project_id
  WHERE n.id = p_id AND p.status IN ('draft','active') AND p.tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('project.err_note_not_editable'); END IF;
  DELETE FROM project.project_note WHERE id = p_id;
  RETURN pgv.toast(pgv.t('project.toast_note_deleted')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', v_pid)));
END;
$function$;
