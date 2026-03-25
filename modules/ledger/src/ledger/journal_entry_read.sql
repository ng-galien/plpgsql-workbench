CREATE OR REPLACE FUNCTION ledger.journal_entry_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_entry record;
  v_lines jsonb;
  v_result jsonb;
  v_balanced boolean;
BEGIN
  SELECT * INTO v_entry FROM ledger.journal_entry
  WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true);
  IF NOT FOUND THEN RETURN NULL; END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.id), '[]'::jsonb) INTO v_lines
  FROM (
    SELECT el.id, el.account_id, a.code AS account_code, a.label AS account_label,
           el.debit, el.credit, el.label
    FROM ledger.entry_line el
    JOIN ledger.account a ON a.id = el.account_id
    WHERE el.journal_entry_id = v_entry.id
    ORDER BY el.id
  ) r;

  v_result := to_jsonb(v_entry) || jsonb_build_object(
    'lines', v_lines,
    'status', CASE WHEN v_entry.posted THEN 'posted' ELSE 'draft' END
  );

  -- HATEOAS actions based on state
  v_balanced := ledger._entry_balanced(v_entry.id);
  IF NOT v_entry.posted THEN
    IF v_balanced THEN
      v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
        jsonb_build_object('method', 'post', 'uri', 'ledger://journal_entry/' || p_id || '/post'),
        jsonb_build_object('method', 'delete', 'uri', 'ledger://journal_entry/' || p_id)
      ));
    ELSE
      v_result := v_result || jsonb_build_object('actions', jsonb_build_array(
        jsonb_build_object('method', 'delete', 'uri', 'ledger://journal_entry/' || p_id)
      ));
    END IF;
  ELSE
    v_result := v_result || jsonb_build_object('actions', '[]'::jsonb);
  END IF;

  RETURN v_result;
END;
$function$;
