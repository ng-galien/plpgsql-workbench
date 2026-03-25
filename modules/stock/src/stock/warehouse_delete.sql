CREATE OR REPLACE FUNCTION stock.warehouse_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row stock.warehouse;
BEGIN
  UPDATE stock.warehouse SET active = false
  WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row);
END;
$function$;
