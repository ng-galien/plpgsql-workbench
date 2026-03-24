CREATE OR REPLACE FUNCTION asset.asset_read(p_id text)
 RETURNS asset.asset
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN (SELECT a FROM asset.asset a WHERE a.id::text = p_id AND a.tenant_id = current_setting('app.tenant_id', true));
END;
$function$;
