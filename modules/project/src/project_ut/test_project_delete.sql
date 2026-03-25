CREATE OR REPLACE FUNCTION project_ut.test_project_delete()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_id int; v_client_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  SELECT id INTO v_client_id FROM crm.client LIMIT 1;
  INSERT INTO project.project (code, client_id, subject) VALUES ('PRJ-UT-DEL', v_client_id, 'UT delete test') RETURNING id INTO v_id;
  UPDATE project.project SET status = 'active' WHERE id = v_id;
  RETURN NEXT throws_ok(format('SELECT project.post_project_delete(%s)', v_id), NULL, 'cannot delete active project');
  UPDATE project.project SET status = 'draft' WHERE id = v_id;
  PERFORM project.post_project_delete(v_id);
  RETURN NEXT ok(NOT EXISTS (SELECT 1 FROM project.project WHERE id = v_id), 'project deleted');
END;
$function$;
