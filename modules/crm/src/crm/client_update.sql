CREATE OR REPLACE FUNCTION crm.client_update(p_row crm.client)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_result crm.client;
BEGIN
  UPDATE crm.client SET
    type = p_row.type,
    name = p_row.name,
    email = p_row.email,
    phone = p_row.phone,
    address = p_row.address,
    city = p_row.city,
    postal_code = p_row.postal_code,
    tier = p_row.tier,
    tags = p_row.tags,
    notes = p_row.notes,
    active = p_row.active
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
