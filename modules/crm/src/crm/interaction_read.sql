CREATE OR REPLACE FUNCTION crm.interaction_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN (
    SELECT to_jsonb(i) || jsonb_build_object('client_name', c.name)
    FROM crm.interaction i
    JOIN crm.client c ON c.id = i.client_id
    WHERE i.id::text = p_id AND i.tenant_id = current_setting('app.tenant_id', true)
  );
END;
$function$;
