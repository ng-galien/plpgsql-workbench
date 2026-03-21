CREATE OR REPLACE FUNCTION docs.library_remove_asset(p_library_id text, p_asset_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_deleted int;
BEGIN
  DELETE FROM docs.library_asset WHERE library_id = p_library_id AND asset_id = p_asset_id;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted > 0;
END;
$function$;
