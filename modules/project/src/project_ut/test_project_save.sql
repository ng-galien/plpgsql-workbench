CREATE OR REPLACE FUNCTION project_ut.test_project_save()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_client_id int; v_id int; v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);
  SELECT id INTO v_client_id FROM crm.client LIMIT 1;
  v_result := project.post_project_save(jsonb_build_object('client_id', v_client_id, 'subject', 'UT save test', 'address', '1 rue Test'));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create returns success toast');
  SELECT id INTO v_id FROM project.project WHERE subject = 'UT save test';
  RETURN NEXT ok(v_id IS NOT NULL, 'project created');
  RETURN NEXT ok((SELECT code FROM project.project WHERE id = v_id) LIKE 'PRJ-%', 'code auto-generated');
  RETURN NEXT is((SELECT address FROM project.project WHERE id = v_id), '1 rue Test', 'address saved');
  v_result := project.post_project_save(jsonb_build_object('id', v_id, 'client_id', v_client_id, 'subject', 'UT save updated'));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'update returns success toast');
  RETURN NEXT is((SELECT subject FROM project.project WHERE id = v_id), 'UT save updated', 'subject updated');
  UPDATE project.project SET status = 'closed' WHERE id = v_id;
  RETURN NEXT throws_ok(
    format('SELECT project.post_project_save(''{"id":%s,"client_id":%s,"subject":"fail"}''::jsonb)', v_id, v_client_id),
    NULL, 'cannot update closed project');
  DELETE FROM project.project WHERE id = v_id;
END;
$function$;
