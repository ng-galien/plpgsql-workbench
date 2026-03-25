CREATE OR REPLACE FUNCTION project.post_milestone_add(p_project_id integer, p_label text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_order int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM project.project WHERE id = p_project_id AND status IN ('draft','active') AND tenant_id = current_setting('app.tenant_id', true)) THEN
    RAISE EXCEPTION '%', pgv.t('project.err_not_editable');
  END IF;
  SELECT COALESCE(max(sort_order), 0) + 1 INTO v_order FROM project.milestone WHERE project_id = p_project_id;
  INSERT INTO project.milestone (project_id, sort_order, label) VALUES (p_project_id, v_order, p_label);
  RETURN pgv.toast(pgv.t('project.toast_milestone_added')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', p_project_id)));
END;
$function$;
