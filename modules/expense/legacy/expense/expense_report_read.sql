CREATE OR REPLACE FUNCTION expense.expense_report_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
  v_status text;
  v_id int;
  v_line_count int;
  v_actions jsonb := '[]'::jsonb;
BEGIN
  v_result := (
    SELECT to_jsonb(r) || jsonb_build_object(
      'lines', COALESCE((
        SELECT jsonb_agg(to_jsonb(lg) || jsonb_build_object('category_name', c.name) ORDER BY lg.expense_date)
        FROM expense.line lg
        LEFT JOIN expense.category c ON c.id = lg.category_id
        WHERE lg.note_id = r.id
      ), '[]'::jsonb),
      'total_excl_tax', COALESCE((SELECT sum(amount_excl_tax) FROM expense.line WHERE note_id = r.id), 0),
      'total_incl_tax', COALESCE((SELECT sum(amount_incl_tax) FROM expense.line WHERE note_id = r.id), 0),
      'line_count', (SELECT count(*) FROM expense.line WHERE note_id = r.id)::int
    )
    FROM expense.expense_report r
    WHERE r.id = p_id::int OR r.reference = p_id
  );
  IF v_result IS NULL THEN RETURN NULL; END IF;

  v_status := v_result->>'status';
  v_id := (v_result->>'id')::int;
  v_line_count := (v_result->>'line_count')::int;

  CASE v_status
    WHEN 'draft' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'edit', 'uri', 'expense://expense_report/' || v_id || '/edit'),
        jsonb_build_object('method', 'add_line', 'uri', 'expense://expense_report/' || v_id || '/add_line')
      );
      IF v_line_count > 0 THEN
        v_actions := v_actions || jsonb_build_array(jsonb_build_object('method', 'submit', 'uri', 'expense://expense_report/' || v_id || '/submit'));
      END IF;
      v_actions := v_actions || jsonb_build_array(jsonb_build_object('method', 'delete', 'uri', 'expense://expense_report/' || v_id || '/delete'));
    WHEN 'submitted' THEN
      v_actions := jsonb_build_array(
        jsonb_build_object('method', 'validate', 'uri', 'expense://expense_report/' || v_id || '/validate'),
        jsonb_build_object('method', 'reject', 'uri', 'expense://expense_report/' || v_id || '/reject')
      );
    WHEN 'validated' THEN
      v_actions := jsonb_build_array(jsonb_build_object('method', 'reimburse', 'uri', 'expense://expense_report/' || v_id || '/reimburse'));
    ELSE
      v_actions := '[]'::jsonb;
  END CASE;

  RETURN v_result || jsonb_build_object('actions', v_actions);
END;
$function$;
