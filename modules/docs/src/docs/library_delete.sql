CREATE OR REPLACE FUNCTION docs.library_delete(p_name text)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_deleted int;
BEGIN
  DELETE FROM docs.library WHERE name = p_name AND tenant_id = current_setting('app.tenant_id', true);
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted > 0;
END;
$function$;
