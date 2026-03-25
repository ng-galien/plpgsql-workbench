CREATE OR REPLACE FUNCTION project.project_create(p_row project.project)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_result jsonb;
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.code := project._next_code();
  p_row.status := COALESCE(NULLIF(p_row.status, ''), 'draft');
  p_row.created_at := now(); p_row.updated_at := now();
  INSERT INTO project.project (code, client_id, estimate_id, subject, address, status, start_date, due_date, notes, created_at, updated_at, tenant_id)
  VALUES (p_row.code, p_row.client_id, p_row.estimate_id, p_row.subject, p_row.address, p_row.status, p_row.start_date, p_row.due_date, p_row.notes, p_row.created_at, p_row.updated_at, p_row.tenant_id)
  RETURNING to_jsonb(project.project.*) INTO v_result;
  RETURN v_result;
END;
$function$;
