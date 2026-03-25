CREATE OR REPLACE FUNCTION hr.employee_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
  v_actions jsonb := '[]'::jsonb;
  v_status text;
  v_cp numeric;
  v_rtt numeric;
  v_hours numeric;
  v_leave_count int;
BEGIN
  SELECT to_jsonb(e) || jsonb_build_object(
    'contract_label', hr.contract_label(e.contract_type),
    'display_name', e.first_name || ' ' || e.last_name
  ) INTO v_result
  FROM hr.employee e
  WHERE e.id = p_id::int AND e.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN RETURN NULL; END IF;

  v_status := v_result->>'status';

  IF v_status = 'active' THEN
    v_actions := jsonb_build_array(
      jsonb_build_object('method', 'deactivate', 'uri', 'hr://employee/' || p_id || '/deactivate'),
      jsonb_build_object('method', 'delete', 'uri', 'hr://employee/' || p_id || '/delete')
    );
  ELSIF v_status = 'inactive' THEN
    v_actions := jsonb_build_array(
      jsonb_build_object('method', 'activate', 'uri', 'hr://employee/' || p_id || '/activate'),
      jsonb_build_object('method', 'delete', 'uri', 'hr://employee/' || p_id || '/delete')
    );
  END IF;

  SELECT COALESCE(lb.allocated - lb.used, 0) INTO v_cp
    FROM hr.leave_balance lb WHERE lb.employee_id = p_id::int AND lb.leave_type = 'paid_leave';
  SELECT COALESCE(lb.allocated - lb.used, 0) INTO v_rtt
    FROM hr.leave_balance lb WHERE lb.employee_id = p_id::int AND lb.leave_type = 'rtt';
  SELECT COALESCE(sum(t.hours), 0) INTO v_hours
    FROM hr.timesheet t WHERE t.employee_id = p_id::int AND t.work_date >= CURRENT_DATE - 30;
  SELECT count(*) INTO v_leave_count
    FROM hr.leave_request a WHERE a.employee_id = p_id::int;

  v_result := v_result || jsonb_build_object(
    'actions', v_actions,
    'cp_remaining', COALESCE(v_cp, 0),
    'rtt_remaining', COALESCE(v_rtt, 0),
    'hours_30d', v_hours,
    'leave_count', v_leave_count
  );

  RETURN v_result;
END;
$function$;
