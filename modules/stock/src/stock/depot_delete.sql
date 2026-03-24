CREATE OR REPLACE FUNCTION stock.depot_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_row stock.depot;
BEGIN
  UPDATE stock.depot SET actif = false
  WHERE id = p_id::int AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row);
END;
$function$;
