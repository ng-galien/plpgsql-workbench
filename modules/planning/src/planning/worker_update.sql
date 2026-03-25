CREATE OR REPLACE FUNCTION planning.worker_update(p_row planning.worker)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE planning.worker SET name = COALESCE(NULLIF(p_row.name, ''), name), role = COALESCE(p_row.role, role), phone = COALESCE(p_row.phone, phone), color = COALESCE(NULLIF(p_row.color, ''), color), active = COALESCE(p_row.active, active)
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true) RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
