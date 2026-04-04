CREATE OR REPLACE FUNCTION hr.timesheet_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT to_jsonb(t) || jsonb_build_object(
    'employee_name', e.first_name || ' ' || e.last_name
  ) INTO v_result
  FROM hr.timesheet t
  JOIN hr.employee e ON e.id = t.employee_id
  WHERE t.id = p_id::int AND t.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN RETURN NULL; END IF;

  v_result := v_result || jsonb_build_object(
    'actions', jsonb_build_array(
      jsonb_build_object('method', 'delete', 'uri', 'hr://timesheet/' || p_id || '/delete')
    )
  );

  RETURN v_result;
END;
$function$;
