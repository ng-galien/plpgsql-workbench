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
END; $function$;
