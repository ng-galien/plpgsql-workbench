CREATE OR REPLACE FUNCTION ledger.journal_entry_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row ledger.journal_entry;
BEGIN
  DELETE FROM ledger.journal_entry
  WHERE id = p_id::int
    AND tenant_id = current_setting('app.tenant_id', true)
    AND NOT posted
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Entry not found or already posted (id=%)', p_id;
  END IF;

  RETURN to_jsonb(v_row);
END;
$function$;
