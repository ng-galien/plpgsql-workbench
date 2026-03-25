CREATE OR REPLACE FUNCTION project_ut.test_milestone_sequential()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_pid int; v_m1 int; v_m2 int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  INSERT INTO project.project (code, client_id, subject, status)
  VALUES ('PRJ-UT-SEQ', (SELECT id FROM crm.client LIMIT 1), 'UT sequential', 'active') RETURNING id INTO v_pid;
  INSERT INTO project.milestone (project_id, sort_order, label) VALUES (v_pid, 1, 'M1') RETURNING id INTO v_m1;
  INSERT INTO project.milestone (project_id, sort_order, label) VALUES (v_pid, 2, 'M2') RETURNING id INTO v_m2;
  RETURN NEXT throws_ok(format('SELECT project.post_milestone_validate(%s)', v_m2), NULL, 'cannot validate M2 before M1');
  PERFORM project.post_milestone_validate(v_m1);
  RETURN NEXT is((SELECT status FROM project.milestone WHERE id = v_m1), 'done', 'M1 validated');
  PERFORM project.post_milestone_validate(v_m2);
  RETURN NEXT is((SELECT status FROM project.milestone WHERE id = v_m2), 'done', 'M2 validated after M1');
  DELETE FROM project.project WHERE id = v_pid;
END;
$function$;
