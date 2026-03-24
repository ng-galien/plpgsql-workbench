CREATE OR REPLACE FUNCTION crm.interaction_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result crm.interaction;
BEGIN
  DELETE FROM crm.interaction
  WHERE id::text = p_id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
