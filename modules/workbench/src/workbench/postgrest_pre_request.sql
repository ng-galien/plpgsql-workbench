CREATE OR REPLACE FUNCTION workbench.postgrest_pre_request()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE v_tenant text;
BEGIN
  v_tenant := coalesce(
    current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id',
    'dev'
  );
  PERFORM set_config('app.tenant_id', v_tenant, true);

  -- Dev tenant: grant all permissions (no auth)
  IF v_tenant = 'dev' THEN
    PERFORM set_config('app.permissions', 'crm.client.create,crm.client.read,crm.client.modify,crm.client.delete,crm.contact.create,crm.contact.read,crm.contact.modify,crm.contact.delete,crm.interaction.create,crm.interaction.read,crm.interaction.modify,crm.interaction.delete', true);
  END IF;
END;
$function$;
