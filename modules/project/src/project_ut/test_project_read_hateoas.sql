CREATE OR REPLACE FUNCTION project_ut.test_project_read_hateoas()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_pid int; v_row jsonb; v_actions jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  INSERT INTO project.project (code, client_id, subject, status)
  VALUES ('PRJ-UT-HAT', (SELECT id FROM crm.client LIMIT 1), 'UT HATEOAS', 'draft') RETURNING id INTO v_pid;
  v_row := project.project_read(v_pid::text);
  v_actions := v_row -> 'actions';
  RETURN NEXT ok(v_actions IS NOT NULL, 'read returns actions');
  RETURN NEXT ok(v_actions @> '[{"method":"start"}]', 'draft has start action');
  RETURN NEXT ok(v_actions @> '[{"method":"edit"}]', 'draft has edit action');
  RETURN NEXT ok(v_actions @> '[{"method":"delete"}]', 'draft has delete action');
  UPDATE project.project SET status = 'active' WHERE id = v_pid;
  v_row := project.project_read(v_pid::text);
  v_actions := v_row -> 'actions';
  RETURN NEXT ok(v_actions @> '[{"method":"review"}]', 'active has review action');
  RETURN NEXT ok(NOT v_actions @> '[{"method":"delete"}]', 'active no delete action');
  UPDATE project.project SET status = 'review' WHERE id = v_pid;
  v_row := project.project_read(v_pid::text);
  v_actions := v_row -> 'actions';
  RETURN NEXT ok(v_actions @> '[{"method":"close"}]', 'review has close action');
  UPDATE project.project SET status = 'closed' WHERE id = v_pid;
  v_row := project.project_read(v_pid::text);
  v_actions := v_row -> 'actions';
  RETURN NEXT is(jsonb_array_length(v_actions), 0, 'closed has no actions');
  DELETE FROM project.project WHERE id = v_pid;
END;
$function$;
