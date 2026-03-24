CREATE OR REPLACE FUNCTION ledger.journal_entry_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT to_jsonb(je) || jsonb_build_object(
      'total_debit', coalesce(sum(el.debit), 0),
      'total_credit', coalesce(sum(el.credit), 0),
      'line_count', count(el.id),
      'status', CASE WHEN je.posted THEN 'posted' ELSE 'draft' END
    )
    FROM ledger.journal_entry je
    LEFT JOIN ledger.entry_line el ON el.journal_entry_id = je.id
    WHERE je.tenant_id = current_setting('app.tenant_id', true)
    GROUP BY je.id
    ORDER BY je.entry_date DESC, je.id DESC;
END;
$function$;
