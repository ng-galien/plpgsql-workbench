CREATE OR REPLACE FUNCTION hr.timesheet_create(p_row hr.timesheet)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.created_at := now();

  INSERT INTO hr.timesheet (tenant_id, employee_id, work_date, hours, description, created_at)
  VALUES (p_row.tenant_id, p_row.employee_id, p_row.work_date, p_row.hours, COALESCE(p_row.description, ''), p_row.created_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
