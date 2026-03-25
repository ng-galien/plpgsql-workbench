CREATE OR REPLACE FUNCTION project.post_note_add(p_project_id integer, p_content text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM project.project WHERE id = p_project_id AND status IN ('draft','active') AND tenant_id = current_setting('app.tenant_id', true)) THEN
    RAISE EXCEPTION '%', pgv.t('project.err_not_editable');
  END IF;
  INSERT INTO project.project_note (project_id, content) VALUES (p_project_id, p_content);
  RETURN pgv.toast(pgv.t('project.toast_note_added')) || pgv.redirect(pgv.call_ref('get_project', jsonb_build_object('p_id', p_project_id)));
END;
$function$;
