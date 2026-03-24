CREATE OR REPLACE FUNCTION crm.client_activate(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result crm.client;
BEGIN
  UPDATE crm.client SET active = true
  WHERE id::text = p_id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
