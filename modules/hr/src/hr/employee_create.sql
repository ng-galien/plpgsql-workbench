CREATE OR REPLACE FUNCTION hr.employee_create(p_row hr.employee)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.created_at := now();
  p_row.updated_at := now();

  INSERT INTO hr.employee (tenant_id, employee_code, last_name, first_name, email, phone, birth_date, gender, nationality, position, qualification, department, contract_type, hire_date, end_date, gross_salary, weekly_hours, status, notes, created_at, updated_at)
  VALUES (p_row.tenant_id, COALESCE(p_row.employee_code, ''), p_row.last_name, p_row.first_name, p_row.email, p_row.phone, p_row.birth_date, COALESCE(p_row.gender, ''), COALESCE(p_row.nationality, ''), COALESCE(p_row.position, ''), COALESCE(p_row.qualification, ''), COALESCE(p_row.department, ''), COALESCE(p_row.contract_type, 'cdi'), COALESCE(p_row.hire_date, CURRENT_DATE), p_row.end_date, p_row.gross_salary, COALESCE(p_row.weekly_hours, 35), COALESCE(p_row.status, 'active'), COALESCE(p_row.notes, ''), p_row.created_at, p_row.updated_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
