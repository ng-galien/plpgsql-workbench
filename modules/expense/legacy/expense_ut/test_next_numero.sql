CREATE OR REPLACE FUNCTION expense_ut.test_next_numero()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_ref1 text; v_ref2 text; v_year text := to_char(now(), 'YYYY'); v_res text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM expense.line; DELETE FROM expense.expense_report;

  v_res := expense.post_report_create('{"author":"Test","start_date":"2026-03-01","end_date":"2026-03-31"}'::jsonb);
  SELECT reference INTO v_ref1 FROM expense.expense_report ORDER BY id DESC LIMIT 1;
  RETURN NEXT is(v_ref1, 'NDF-' || v_year || '-001', 'first report gets NDF-YYYY-001');

  v_res := expense.post_report_create('{"author":"Test","start_date":"2026-03-01","end_date":"2026-03-31"}'::jsonb);
  SELECT reference INTO v_ref2 FROM expense.expense_report ORDER BY id DESC LIMIT 1;
  RETURN NEXT is(v_ref2, 'NDF-' || v_year || '-002', 'second report gets NDF-YYYY-002');

  DELETE FROM expense.line; DELETE FROM expense.expense_report;
END;
$function$;
