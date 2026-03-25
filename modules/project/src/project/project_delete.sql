CREATE OR REPLACE FUNCTION project.project_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_result jsonb;
BEGIN
  DELETE FROM project.project WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING to_jsonb(project.project.*) INTO v_result;
  RETURN v_result;
END;
$function$;
