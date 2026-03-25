CREATE OR REPLACE FUNCTION ledger.journal_entry_update(p_row ledger.journal_entry)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE ledger.journal_entry
  SET entry_date = coalesce(p_row.entry_date, entry_date),
      reference = coalesce(p_row.reference, reference),
      description = coalesce(p_row.description, description)
  WHERE id = p_row.id
    AND tenant_id = current_setting('app.tenant_id', true)
    AND NOT posted
  RETURNING * INTO p_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Entry not found or already posted (id=%)', p_row.id;
  END IF;

  RETURN to_jsonb(p_row);
END;
$function$;
