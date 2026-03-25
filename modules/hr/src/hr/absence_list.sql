CREATE OR REPLACE FUNCTION hr.absence_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT to_jsonb(a) || jsonb_build_object(
      'employee_name', e.first_name || ' ' || e.last_name,
      'type_label', hr.leave_type_label(a.leave_type)
    )
    FROM hr.leave_request a
    JOIN hr.employee e ON e.id = a.employee_id
    WHERE a.tenant_id = current_setting('app.tenant_id', true)
    ORDER BY a.start_date DESC;
END;
$function$;
