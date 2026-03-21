CREATE OR REPLACE FUNCTION docs.charte_read(p_id text)
 RETURNS docs.charte
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN (SELECT c FROM docs.charte c WHERE (c.slug = p_id OR c.id = p_id) AND c.tenant_id = current_setting('app.tenant_id', true));
END;
$function$;
