CREATE OR REPLACE FUNCTION expense_ut.test_workflow()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_id int; v_res text; v_status text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM expense.line; DELETE FROM expense.expense_report;

  -- Create report
  v_res := expense.post_report_create('{"author":"Alice","start_date":"2026-03-01","end_date":"2026-03-31"}'::jsonb);
  RETURN NEXT ok(v_res LIKE '%data-toast="success"%', 'report created');
  SELECT id INTO v_id FROM expense.expense_report ORDER BY id DESC LIMIT 1;

  -- Submit without lines -> fail
  v_res := expense.post_report_submit(jsonb_build_object('id', v_id));
  RETURN NEXT ok(v_res LIKE '%error%', 'cannot submit without lines');

  -- Add line
  v_res := expense.post_line_add(jsonb_build_object(
    'note_id', v_id, 'expense_date', '2026-03-05',
    'description', 'Client meal', 'amount_excl_tax', 25.00, 'vat', 5.00,
    'category_id', (SELECT id FROM expense.category WHERE name = 'Meals')
  ));
  RETURN NEXT ok(v_res LIKE '%data-toast="success"%', 'line added');

  -- Submit
  v_res := expense.post_report_submit(jsonb_build_object('id', v_id));
  RETURN NEXT ok(v_res LIKE '%data-toast="success"%', 'report submitted');
  SELECT status INTO v_status FROM expense.expense_report WHERE id = v_id;
  RETURN NEXT is(v_status, 'submitted', 'status is submitted');

  -- Cannot add line after submit
  v_res := expense.post_line_add(jsonb_build_object(
    'note_id', v_id, 'expense_date', '2026-03-06',
    'description', 'Should fail', 'amount_excl_tax', 10.00
  ));
  RETURN NEXT ok(v_res LIKE '%error%', 'cannot add line to submitted report');

  -- Validate
  v_res := expense.post_report_validate(jsonb_build_object('id', v_id));
  RETURN NEXT ok(v_res LIKE '%data-toast="success"%', 'report validated');
  SELECT status INTO v_status FROM expense.expense_report WHERE id = v_id;
  RETURN NEXT is(v_status, 'validated', 'status is validated');

  -- Reimburse
  v_res := expense.post_report_reimburse(jsonb_build_object('id', v_id));
  RETURN NEXT ok(v_res LIKE '%data-toast="success"%', 'report reimbursed');
  SELECT status INTO v_status FROM expense.expense_report WHERE id = v_id;
  RETURN NEXT is(v_status, 'reimbursed', 'status is reimbursed');

  DELETE FROM expense.line; DELETE FROM expense.expense_report;
END;
$function$;
