CREATE OR REPLACE FUNCTION ledger.account_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT to_jsonb(a) || jsonb_build_object(
    'balance', coalesce(sum(el.debit) - sum(el.credit), 0),
    'line_count', count(el.id)
  ) INTO v_result
  FROM ledger.account a
  LEFT JOIN ledger.entry_line el ON el.account_id = a.id
  WHERE (a.id = p_id::int OR a.code = p_id)
    AND a.tenant_id = current_setting('app.tenant_id', true)
  GROUP BY a.id;

  IF v_result IS NULL THEN RETURN NULL; END IF;

  -- HATEOAS actions based on state
  IF (v_result->>'line_count')::int = 0 THEN
    v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
      jsonb_build_object('method', 'delete', 'uri', 'ledger://account/' || (v_result->>'id'))
    ));
  ELSE
    v_result := v_result || jsonb_build_object('actions', '[]'::jsonb);
  END IF;

  RETURN v_result;
END;
$function$;
