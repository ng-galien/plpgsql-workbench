CREATE OR REPLACE FUNCTION stock.warehouse_update(p_row stock.warehouse)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE stock.warehouse SET
    name = COALESCE(NULLIF(p_row.name, ''), name),
    type = COALESCE(NULLIF(p_row.type, ''), type),
    address = COALESCE(p_row.address, address),
    active = COALESCE(p_row.active, active)
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
