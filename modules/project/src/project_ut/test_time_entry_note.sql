CREATE OR REPLACE FUNCTION project_ut.test_time_entry_note()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_pid int; v_tid int; v_nid int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  INSERT INTO project.project (code, client_id, subject, status)
  VALUES ('PRJ-UT-TN', (SELECT id FROM crm.client LIMIT 1), 'UT time/note', 'active') RETURNING id INTO v_pid;
  PERFORM project.post_time_entry_add(v_pid, 7.5, 'Work UT');
  SELECT id INTO v_tid FROM project.time_entry WHERE project_id = v_pid;
  RETURN NEXT ok(v_tid IS NOT NULL, 'time entry created');
  RETURN NEXT is((SELECT hours FROM project.time_entry WHERE id = v_tid), 7.5::numeric, 'hours saved');
  RETURN NEXT is((SELECT description FROM project.time_entry WHERE id = v_tid), 'Work UT', 'description saved');
  PERFORM project.post_time_entry_delete(v_tid);
  RETURN NEXT ok(NOT EXISTS (SELECT 1 FROM project.time_entry WHERE id = v_tid), 'time entry deleted');
  PERFORM project.post_note_add(v_pid, 'Note UT test');
  SELECT id INTO v_nid FROM project.project_note WHERE project_id = v_pid;
  RETURN NEXT ok(v_nid IS NOT NULL, 'note created');
  RETURN NEXT is((SELECT content FROM project.project_note WHERE id = v_nid), 'Note UT test', 'content saved');
  PERFORM project.post_note_delete(v_nid);
  RETURN NEXT ok(NOT EXISTS (SELECT 1 FROM project.project_note WHERE id = v_nid), 'note deleted');
  UPDATE project.project SET status = 'closed' WHERE id = v_pid;
  RETURN NEXT throws_ok(format('SELECT project.post_time_entry_add(%s, 1, ''fail'')', v_pid), NULL, 'cannot add time entry to closed');
  RETURN NEXT throws_ok(format('SELECT project.post_note_add(%s, ''fail'')', v_pid), NULL, 'cannot add note to closed');
  DELETE FROM project.project WHERE id = v_pid;
END;
$function$;
