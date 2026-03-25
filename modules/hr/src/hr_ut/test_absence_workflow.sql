CREATE OR REPLACE FUNCTION hr_ut.test_absence_workflow()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_emp_id int;
  v_abs_id int;
  v_used numeric;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  INSERT INTO hr.employee (last_name, first_name) VALUES ('Test', 'Absence') RETURNING id INTO v_emp_id;

  -- Declare leave request
  v_result := hr.post_absence_save(jsonb_build_object(
    'employee_id', v_emp_id, 'leave_type', 'paid_leave',
    'start_date', '2026-04-01', 'end_date', '2026-04-05', 'day_count', 5
  ));
  RETURN NEXT ok(v_result LIKE '%déclarée%', 'leave request declared');

  SELECT id INTO v_abs_id FROM hr.leave_request WHERE employee_id = v_emp_id;
  RETURN NEXT ok(v_abs_id IS NOT NULL, 'leave request inserted');
  RETURN NEXT is((SELECT status FROM hr.leave_request WHERE id = v_abs_id), 'pending', 'initial status is pending');

  -- Validate
  v_result := hr.post_absence_validate(jsonb_build_object('id', v_abs_id, 'action', 'validate'));
  RETURN NEXT ok(v_result LIKE '%approved%', 'validate returns success');
  RETURN NEXT is((SELECT status FROM hr.leave_request WHERE id = v_abs_id), 'approved', 'status updated to approved');

  -- Cannot validate again
  v_result := hr.post_absence_validate(jsonb_build_object('id', v_abs_id, 'action', 'refuse'));
  RETURN NEXT ok(v_result LIKE '%déjà traitée%', 'double validation rejected');

  -- Date validation
  v_result := hr.post_absence_save(jsonb_build_object(
    'employee_id', v_emp_id, 'leave_type', 'rtt',
    'start_date', '2026-04-10', 'end_date', '2026-04-05', 'day_count', 3
  ));
  RETURN NEXT ok(v_result LIKE '%après la date%', 'end_date < start_date rejected');

  -- Leave balance: setup
  DELETE FROM hr.leave_request WHERE employee_id = v_emp_id;
  INSERT INTO hr.leave_balance (employee_id, leave_type, allocated, used)
    VALUES (v_emp_id, 'paid_leave', 25, 0);

  -- Declare + validate: should decrement used
  v_result := hr.post_absence_save(jsonb_build_object(
    'employee_id', v_emp_id, 'leave_type', 'paid_leave',
    'start_date', '2026-06-01', 'end_date', '2026-06-05', 'day_count', 5
  ));
  SELECT id INTO v_abs_id FROM hr.leave_request WHERE employee_id = v_emp_id AND start_date = '2026-06-01';
  v_result := hr.post_absence_validate(jsonb_build_object('id', v_abs_id, 'action', 'validate'));
  SELECT used INTO v_used FROM hr.leave_balance WHERE employee_id = v_emp_id AND leave_type = 'paid_leave';
  RETURN NEXT is(v_used, 5::numeric, 'balance decremented after validation');

  -- Declare with insufficient balance: should warn
  UPDATE hr.leave_balance SET allocated = 25, used = 23 WHERE employee_id = v_emp_id AND leave_type = 'paid_leave';
  v_result := hr.post_absence_save(jsonb_build_object(
    'employee_id', v_emp_id, 'leave_type', 'paid_leave',
    'start_date', '2026-07-01', 'end_date', '2026-07-05', 'day_count', 5
  ));
  RETURN NEXT ok(v_result LIKE '%insuffisant%', 'warning on insufficient balance at declaration');

  -- Validate with insufficient balance: should block
  SELECT id INTO v_abs_id FROM hr.leave_request WHERE employee_id = v_emp_id AND start_date = '2026-07-01';
  v_result := hr.post_absence_validate(jsonb_build_object('id', v_abs_id, 'action', 'validate'));
  RETURN NEXT ok(v_result LIKE '%insuffisant%', 'validation blocked on insufficient balance');
  RETURN NEXT is((SELECT status FROM hr.leave_request WHERE id = v_abs_id), 'pending', 'leave request stays pending when balance insufficient');

  -- Cleanup
  DELETE FROM hr.leave_balance WHERE employee_id = v_emp_id;
  DELETE FROM hr.leave_request WHERE employee_id = v_emp_id;
  DELETE FROM hr.employee WHERE id = v_emp_id;
END;
$function$;
