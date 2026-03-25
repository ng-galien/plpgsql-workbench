CREATE OR REPLACE FUNCTION project_ut.test_project_lifecycle()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_id int; v_status text;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  RETURN NEXT has_function('project', 'post_project_save', 'post_project_save exists');
  PERFORM project.post_project_save(jsonb_build_object('client_id', (SELECT id FROM crm.client LIMIT 1), 'subject', 'Test lifecycle'));
  SELECT id INTO v_id FROM project.project WHERE subject = 'Test lifecycle';
  RETURN NEXT ok(v_id IS NOT NULL, 'project created');
  SELECT status INTO v_status FROM project.project WHERE id = v_id;
  RETURN NEXT is(v_status, 'draft', 'initial status is draft');
  PERFORM project.post_project_start(v_id);
  SELECT status INTO v_status FROM project.project WHERE id = v_id;
  RETURN NEXT is(v_status, 'active', 'status after start is active');
  PERFORM project.post_project_review(v_id);
  SELECT status INTO v_status FROM project.project WHERE id = v_id;
  RETURN NEXT is(v_status, 'review', 'status after review');
  PERFORM project.post_project_close(v_id);
  SELECT status INTO v_status FROM project.project WHERE id = v_id;
  RETURN NEXT is(v_status, 'closed', 'status after close');
  DELETE FROM project.project WHERE id = v_id;
END;
$function$;
