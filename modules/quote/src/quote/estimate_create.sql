CREATE OR REPLACE FUNCTION quote.estimate_create(p_row quote.estimate)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.number := quote._next_number('EST');
  p_row.status := coalesce(p_row.status, 'draft');
  p_row.notes := coalesce(p_row.notes, '');
  p_row.validity_days := coalesce(p_row.validity_days, 30);
  p_row.created_at := now();
  p_row.updated_at := now();

  INSERT INTO quote.estimate (number, client_id, subject, status, notes, validity_days, tenant_id, created_at, updated_at)
  VALUES (p_row.number, p_row.client_id, p_row.subject, p_row.status, p_row.notes, p_row.validity_days, p_row.tenant_id, p_row.created_at, p_row.updated_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
