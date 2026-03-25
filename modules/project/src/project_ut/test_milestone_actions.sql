CREATE OR REPLACE FUNCTION project_ut.test_milestone_actions()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_pid int; v_mid int; v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  INSERT INTO project.project (code, client_id, subject, status)
  VALUES ('PRJ-UT-MS', (SELECT id FROM crm.client LIMIT 1), 'UT milestone', 'active') RETURNING id INTO v_pid;
  v_result := project.post_milestone_add(v_pid, 'Milestone UT');
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'milestone add returns toast');
  SELECT id INTO v_mid FROM project.milestone WHERE project_id = v_pid AND label = 'Milestone UT';
  RETURN NEXT ok(v_mid IS NOT NULL, 'milestone created');
  RETURN NEXT is((SELECT progress_pct FROM project.milestone WHERE id = v_mid), 0::numeric, 'initial pct is 0');
  PERFORM project.post_milestone_advance(v_mid, 50);
  RETURN NEXT is((SELECT progress_pct FROM project.milestone WHERE id = v_mid), 50::numeric, 'pct updated to 50');
  RETURN NEXT is((SELECT status FROM project.milestone WHERE id = v_mid), 'in_progress', 'status auto in_progress');
  PERFORM project.post_milestone_advance(v_mid, 100);
  RETURN NEXT is((SELECT status FROM project.milestone WHERE id = v_mid), 'done', 'pct 100 -> auto done');
  PERFORM project.post_milestone_delete(v_mid);
  RETURN NEXT ok(NOT EXISTS (SELECT 1 FROM project.milestone WHERE id = v_mid), 'milestone deleted');
  UPDATE project.project SET status = 'closed' WHERE id = v_pid;
  RETURN NEXT throws_ok(format('SELECT project.post_milestone_add(%s, ''test'')', v_pid), NULL, 'cannot add milestone to closed');
  DELETE FROM project.project WHERE id = v_pid;
END;
$function$;
