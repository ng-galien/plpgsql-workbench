CREATE OR REPLACE FUNCTION hr.timesheet_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT to_jsonb(t) || jsonb_build_object(
    'employee_name', e.prenom || ' ' || e.nom
  ) INTO v_result
  FROM hr.timesheet t
  JOIN hr.employee e ON e.id = t.employee_id
  WHERE t.id = p_id::int AND t.tenant_id = current_setting('app.tenant_id', true);

  RETURN v_result;
END;
$function$;
