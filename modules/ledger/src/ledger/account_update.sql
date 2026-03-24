CREATE OR REPLACE FUNCTION ledger.account_update(p_row ledger.account)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE ledger.account
  SET code = coalesce(p_row.code, code),
      label = coalesce(p_row.label, label),
      type = coalesce(p_row.type, type),
      parent_code = p_row.parent_code,
      active = coalesce(p_row.active, active)
  WHERE id = p_row.id
    AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Account not found (id=%)', p_row.id;
  END IF;

  RETURN to_jsonb(p_row);
END;
$function$;
