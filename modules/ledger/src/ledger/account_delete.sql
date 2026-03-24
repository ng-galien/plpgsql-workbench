CREATE OR REPLACE FUNCTION ledger.account_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row ledger.account;
BEGIN
  IF EXISTS (SELECT 1 FROM ledger.entry_line WHERE account_id = p_id::int) THEN
    RAISE EXCEPTION 'Account has entry lines, cannot delete (id=%)', p_id;
  END IF;

  DELETE FROM ledger.account
  WHERE id = p_id::int
    AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Account not found (id=%)', p_id;
  END IF;

  RETURN to_jsonb(v_row);
END;
$function$;
