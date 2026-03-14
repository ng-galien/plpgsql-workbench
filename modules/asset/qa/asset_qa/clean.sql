CREATE OR REPLACE FUNCTION asset_qa.clean()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM asset.asset WHERE tenant_id = 'dev';
END;
$function$;
