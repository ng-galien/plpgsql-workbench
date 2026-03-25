CREATE OR REPLACE FUNCTION planning.worker_create(p_row planning.worker)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.active := COALESCE(p_row.active, true);
  p_row.color := COALESCE(p_row.color, '#3b82f6');
  p_row.created_at := now();
  INSERT INTO planning.worker (tenant_id, name, role, phone, color, active, created_at) VALUES (p_row.tenant_id, p_row.name, COALESCE(p_row.role, ''), p_row.phone, p_row.color, p_row.active, p_row.created_at) RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
