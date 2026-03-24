CREATE OR REPLACE FUNCTION asset.asset_delete(p_id text)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_deleted int;
BEGIN
  DELETE FROM asset.asset
  WHERE id::text = p_id AND tenant_id = current_setting('app.tenant_id', true);
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted > 0;
END;
$function$;
