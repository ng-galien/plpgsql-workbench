CREATE OR REPLACE FUNCTION hr.timesheet_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT to_jsonb(t) || jsonb_build_object(
      'employee_name', e.prenom || ' ' || e.nom
    )
    FROM hr.timesheet t
    JOIN hr.employee e ON e.id = t.employee_id
    WHERE t.tenant_id = current_setting('app.tenant_id', true)
    ORDER BY t.date_travail DESC;
END;
$function$;
