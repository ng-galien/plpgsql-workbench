CREATE OR REPLACE FUNCTION expense.expense_report_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(r) || jsonb_build_object(
        'line_count', COALESCE(l.cnt, 0),
        'total_excl_tax', COALESCE(l.sum_excl, 0),
        'total_incl_tax', COALESCE(l.sum_incl, 0)
      )
      FROM expense.expense_report r
      LEFT JOIN LATERAL (
        SELECT count(*) as cnt, sum(amount_excl_tax) as sum_excl, sum(amount_incl_tax) as sum_incl
        FROM expense.line WHERE note_id = r.id
      ) l ON true
      ORDER BY r.updated_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(r) || jsonb_build_object(
        ''line_count'', COALESCE(l.cnt, 0),
        ''total_excl_tax'', COALESCE(l.sum_excl, 0),
        ''total_incl_tax'', COALESCE(l.sum_incl, 0)
      )
      FROM expense.expense_report r
      LEFT JOIN LATERAL (
        SELECT count(*) as cnt, sum(amount_excl_tax) as sum_excl, sum(amount_incl_tax) as sum_incl
        FROM expense.line WHERE note_id = r.id
      ) l ON true
      WHERE ' || pgv.rsql_to_where(p_filter, 'expense', 'expense_report')
      || ' ORDER BY r.updated_at DESC';
  END IF;
END;
$function$;
