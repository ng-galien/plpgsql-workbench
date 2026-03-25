CREATE OR REPLACE FUNCTION project.post_milestone_advance(p_id integer, p_pct numeric)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_pid int; v_new_status text;
BEGIN
  SELECT m.project_id INTO v_pid FROM project.milestone m JOIN project.project p ON p.id = m.project_id
  WHERE m.id = p_id AND p.status IN ('draft','active') AND p.tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('project.err_milestone_not_editable'); END IF;
  v_new_status := CASE WHEN p_pct >= 100 THEN 'done' WHEN p_pct > 0 THEN 'in_progress' ELSE 'todo' END;
  UPDATE project.milestone SET progress_pct = p_pct, status = v_new_status WHERE id = p_id;
  RETURN pgv.toast(pgv.t('project.toast_progress_updated')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', v_pid)));
END;
$function$;
