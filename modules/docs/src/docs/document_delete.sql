CREATE OR REPLACE FUNCTION docs.document_delete(p_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SET "api.expose" TO 'mcp'
AS $function$
DECLARE
  v_deleted int;
BEGIN
  DELETE FROM docs.document
  WHERE (slug = p_id OR id = p_id) AND tenant_id = current_setting('app.tenant_id', true);
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted > 0;
END;
$function$;
