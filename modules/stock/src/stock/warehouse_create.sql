CREATE OR REPLACE FUNCTION stock.warehouse_create(p_row stock.warehouse)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.created_at := now();

  INSERT INTO stock.warehouse (tenant_id, name, type, address, active, created_at)
  VALUES (p_row.tenant_id, p_row.name, p_row.type, p_row.address, coalesce(p_row.active, true), p_row.created_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
