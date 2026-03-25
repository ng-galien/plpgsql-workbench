CREATE OR REPLACE FUNCTION hr.absence_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
  v_actions jsonb := '[]'::jsonb;
  v_status text;
  v_balance numeric;
BEGIN
  SELECT to_jsonb(a) || jsonb_build_object(
    'employee_name', e.first_name || ' ' || e.last_name,
    'type_label', hr.leave_type_label(a.leave_type)
  ) INTO v_result
  FROM hr.leave_request a
  JOIN hr.employee e ON e.id = a.employee_id
  WHERE a.id = p_id::int AND a.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN RETURN NULL; END IF;

  v_status := v_result->>'status';

  IF v_status = 'pending' THEN
    v_actions := jsonb_build_array(
      jsonb_build_object('method', 'validate', 'uri', 'hr://absence/' || p_id || '/validate'),
      jsonb_build_object('method', 'refuse', 'uri', 'hr://absence/' || p_id || '/refuse'),
      jsonb_build_object('method', 'cancel', 'uri', 'hr://absence/' || p_id || '/cancel'),
      jsonb_build_object('method', 'delete', 'uri', 'hr://absence/' || p_id || '/delete')
    );
  END IF;

  SELECT (lb.allocated - lb.used) INTO v_balance
    FROM hr.leave_balance lb
   WHERE lb.employee_id = (v_result->>'employee_id')::int
     AND lb.leave_type = v_result->>'leave_type';

  v_result := v_result || jsonb_build_object(
    'actions', v_actions,
    'balance_remaining', COALESCE(v_balance, 0)
  );

  RETURN v_result;
END;
$function$;
