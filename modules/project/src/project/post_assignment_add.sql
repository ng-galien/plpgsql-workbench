CREATE OR REPLACE FUNCTION project.post_assignment_add(p_project_id integer, p_worker_name text, p_role text DEFAULT ''::text, p_planned_hours numeric DEFAULT NULL::numeric)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM project.project WHERE id = p_project_id AND status != 'closed' AND tenant_id = current_setting('app.tenant_id', true)) THEN
    RAISE EXCEPTION '%', pgv.t('project.err_project_closed');
  END IF;
  INSERT INTO project.assignment (project_id, worker_name, role, planned_hours) VALUES (p_project_id, p_worker_name, p_role, p_planned_hours);
  RETURN pgv.toast(pgv.t('project.toast_assignment_added')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', p_project_id)));
END;
$function$;
