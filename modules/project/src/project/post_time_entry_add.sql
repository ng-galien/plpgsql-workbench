CREATE OR REPLACE FUNCTION project.post_time_entry_add(p_project_id integer, p_hours numeric, p_description text DEFAULT ''::text, p_date date DEFAULT CURRENT_DATE)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM project.project WHERE id = p_project_id AND status IN ('draft','active') AND tenant_id = current_setting('app.tenant_id', true)) THEN
    RAISE EXCEPTION '%', pgv.t('project.err_not_editable');
  END IF;
  INSERT INTO project.time_entry (project_id, hours, description, entry_date) VALUES (p_project_id, p_hours, p_description, p_date);
  RETURN pgv.toast(pgv.t('project.toast_time_entry_added')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', p_project_id)));
END;
$function$;
