CREATE OR REPLACE FUNCTION crm.interaction_update(p_row crm.interaction)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result crm.interaction;
BEGIN
  UPDATE crm.interaction SET
    type = p_row.type,
    subject = p_row.subject,
    body = p_row.body
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
