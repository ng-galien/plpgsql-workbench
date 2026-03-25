CREATE OR REPLACE FUNCTION project.project_update(p_row project.project)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_result jsonb;
BEGIN
  UPDATE project.project SET client_id = COALESCE(p_row.client_id, client_id), estimate_id = COALESCE(p_row.estimate_id, estimate_id),
    subject = COALESCE(NULLIF(p_row.subject, ''), subject), address = COALESCE(p_row.address, address),
    start_date = COALESCE(p_row.start_date, start_date), due_date = COALESCE(p_row.due_date, due_date),
    notes = COALESCE(p_row.notes, notes), updated_at = now()
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING to_jsonb(project.project.*) INTO v_result;
  RETURN v_result;
END;
$function$;
