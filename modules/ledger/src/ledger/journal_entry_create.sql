CREATE OR REPLACE FUNCTION ledger.journal_entry_create(p_row ledger.journal_entry)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.posted := false;
  p_row.created_at := now();

  INSERT INTO ledger.journal_entry (entry_date, reference, description, posted, tenant_id, created_at)
  VALUES (coalesce(p_row.entry_date, CURRENT_DATE), p_row.reference, p_row.description, p_row.posted, p_row.tenant_id, p_row.created_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
