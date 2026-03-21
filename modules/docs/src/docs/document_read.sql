CREATE OR REPLACE FUNCTION docs.document_read(p_id text)
 RETURNS docs.document
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN (SELECT d FROM docs.document d WHERE d.id = p_id AND d.tenant_id = current_setting('app.tenant_id', true));
END;
$function$;
