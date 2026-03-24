CREATE OR REPLACE FUNCTION ledger.account_create(p_row ledger.account)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.active := coalesce(p_row.active, true);
  p_row.created_at := now();

  INSERT INTO ledger.account (code, label, type, parent_code, active, tenant_id, created_at)
  VALUES (p_row.code, p_row.label, p_row.type, p_row.parent_code, p_row.active, p_row.tenant_id, p_row.created_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
