CREATE OR REPLACE FUNCTION docs.document_read(p_id text)
 RETURNS docs.document
 LANGUAGE plpgsql
 STABLE
 SET "api.expose" TO 'mcp'
AS $function$
BEGIN
  RETURN (SELECT d FROM docs.document d WHERE (d.slug = p_id OR d.id = p_id) AND d.tenant_id = current_setting('app.tenant_id', true));
END;
$function$;
