CREATE OR REPLACE FUNCTION crm.client_create(p_row crm.client)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_result crm.client;
BEGIN
  INSERT INTO crm.client (type, name, email, phone, address, city, postal_code, tier, tags, notes, active)
  VALUES (p_row.type, p_row.name, p_row.email, p_row.phone, p_row.address, p_row.city, p_row.postal_code,
          COALESCE(p_row.tier, 'standard'), COALESCE(p_row.tags, '{}'), COALESCE(p_row.notes, ''), COALESCE(p_row.active, true))
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
