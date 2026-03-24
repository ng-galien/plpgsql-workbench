CREATE OR REPLACE FUNCTION crm.interaction_create(p_row crm.interaction)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result crm.interaction;
BEGIN
  INSERT INTO crm.interaction (client_id, type, subject, body)
  VALUES (p_row.client_id, p_row.type, p_row.subject, COALESCE(p_row.body, ''))
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
