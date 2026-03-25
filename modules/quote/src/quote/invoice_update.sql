CREATE OR REPLACE FUNCTION quote.invoice_update(p_row quote.invoice)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM quote.invoice WHERE id = p_row.id AND status = 'draft' AND tenant_id = current_setting('app.tenant_id', true)) THEN
    RAISE EXCEPTION '%', pgv.t('quote.err_draft_only');
  END IF;

  UPDATE quote.invoice SET
    client_id = coalesce(p_row.client_id, client_id),
    subject = coalesce(nullif(p_row.subject, ''), subject),
    notes = coalesce(p_row.notes, notes),
    updated_at = now()
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
