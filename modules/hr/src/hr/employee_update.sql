CREATE OR REPLACE FUNCTION hr.employee_update(p_row hr.employee)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE hr.employee SET
    employee_code = COALESCE(NULLIF(p_row.employee_code, ''), employee_code),
    last_name = COALESCE(NULLIF(p_row.last_name, ''), last_name),
    first_name = COALESCE(NULLIF(p_row.first_name, ''), first_name),
    email = COALESCE(p_row.email, email),
    phone = COALESCE(p_row.phone, phone),
    birth_date = COALESCE(p_row.birth_date, birth_date),
    gender = COALESCE(NULLIF(p_row.gender, ''), gender),
    nationality = COALESCE(NULLIF(p_row.nationality, ''), nationality),
    position = COALESCE(NULLIF(p_row.position, ''), position),
    qualification = COALESCE(NULLIF(p_row.qualification, ''), qualification),
    department = COALESCE(NULLIF(p_row.department, ''), department),
    contract_type = COALESCE(NULLIF(p_row.contract_type, ''), contract_type),
    hire_date = COALESCE(p_row.hire_date, hire_date),
    end_date = p_row.end_date,
    gross_salary = COALESCE(p_row.gross_salary, gross_salary),
    weekly_hours = COALESCE(p_row.weekly_hours, weekly_hours),
    status = COALESCE(NULLIF(p_row.status, ''), status),
    notes = COALESCE(p_row.notes, notes),
    updated_at = now()
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
