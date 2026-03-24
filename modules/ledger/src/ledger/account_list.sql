CREATE OR REPLACE FUNCTION ledger.account_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
    SELECT to_jsonb(a) || jsonb_build_object(
      'balance', coalesce(sum(el.debit) - sum(el.credit), 0),
      'type_label', ledger._type_label(a.type)
    )
    FROM ledger.account a
    LEFT JOIN ledger.entry_line el ON el.account_id = a.id
    WHERE a.tenant_id = current_setting('app.tenant_id', true)
    GROUP BY a.id
    ORDER BY a.code;
END;
$function$;
