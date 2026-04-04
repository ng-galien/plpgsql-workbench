CREATE OR REPLACE FUNCTION hr_ut.test_timesheet()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_emp_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  INSERT INTO hr.employee (last_name, first_name) VALUES ('Test', 'Hours') RETURNING id INTO v_emp_id;

  -- Save timesheet
  v_result := hr.post_timesheet_save(jsonb_build_object(
    'employee_id', v_emp_id, 'work_date', '2026-03-10', 'hours', 8, 'description', 'Dev feature X'
  ));
  RETURN NEXT ok(v_result LIKE '%enregistrées%', 'timesheet saved');
  RETURN NEXT is(
    (SELECT hours FROM hr.timesheet WHERE employee_id = v_emp_id AND work_date = '2026-03-10'),
    8::numeric, 'hours stored correctly'
  );

  -- Upsert (same date)
  v_result := hr.post_timesheet_save(jsonb_build_object(
    'employee_id', v_emp_id, 'work_date', '2026-03-10', 'hours', 7.5, 'description', 'Updated'
  ));
  RETURN NEXT ok(v_result LIKE '%enregistrées%', 'upsert works');
  RETURN NEXT is(
    (SELECT hours FROM hr.timesheet WHERE employee_id = v_emp_id AND work_date = '2026-03-10'),
    7.5::numeric, 'hours updated via upsert'
  );
  RETURN NEXT is(
    (SELECT count(*)::int FROM hr.timesheet WHERE employee_id = v_emp_id AND work_date = '2026-03-10'),
    1, 'only one row per employee+date'
  );

  -- Validation
  v_result := hr.post_timesheet_save(jsonb_build_object(
    'employee_id', v_emp_id, 'work_date', '2026-03-11', 'hours', 25
  ));
  RETURN NEXT ok(v_result LIKE '%entre 0 et 24%', 'hours > 24 rejected');

  -- Cleanup
  DELETE FROM hr.timesheet WHERE employee_id = v_emp_id;
  DELETE FROM hr.employee WHERE id = v_emp_id;
END;
$function$;
