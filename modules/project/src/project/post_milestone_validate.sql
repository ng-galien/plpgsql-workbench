CREATE OR REPLACE FUNCTION project.post_milestone_validate(p_id integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_pid int; v_order int;
BEGIN
  SELECT m.project_id, m.sort_order INTO v_pid, v_order FROM project.milestone m JOIN project.project p ON p.id = m.project_id
  WHERE m.id = p_id AND m.status != 'done' AND p.status IN ('draft','active') AND p.tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RAISE EXCEPTION '%', pgv.t('project.err_milestone_already_done'); END IF;
  IF EXISTS (SELECT 1 FROM project.milestone WHERE project_id = v_pid AND sort_order < v_order AND status != 'done') THEN
    RAISE EXCEPTION '%', pgv.t('project.err_previous_milestones');
  END IF;
  UPDATE project.milestone SET progress_pct = 100, status = 'done', actual_date = CURRENT_DATE WHERE id = p_id;
  RETURN pgv.toast(pgv.t('project.toast_milestone_validated')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', v_pid)));
END;
$function$;
