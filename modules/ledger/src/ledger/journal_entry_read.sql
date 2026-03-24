CREATE OR REPLACE FUNCTION ledger.journal_entry_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_entry record;
  v_lines jsonb;
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

  RETURN to_jsonb(v_entry) || jsonb_build_object('lines', v_lines);
END;
$function$;
