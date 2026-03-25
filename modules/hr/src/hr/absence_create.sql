CREATE OR REPLACE FUNCTION hr.absence_create(p_row hr.leave_request)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.created_at := now();

  INSERT INTO hr.leave_request (tenant_id, employee_id, leave_type, start_date, end_date, day_count, reason, status, created_at)
  VALUES (p_row.tenant_id, p_row.employee_id, COALESCE(p_row.leave_type, 'paid_leave'), p_row.start_date, p_row.end_date, COALESCE(p_row.day_count, 1), COALESCE(p_row.reason, ''), COALESCE(p_row.status, 'pending'), p_row.created_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
