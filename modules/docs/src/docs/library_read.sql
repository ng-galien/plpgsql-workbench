CREATE OR REPLACE FUNCTION docs.library_read(p_id text)
 RETURNS docs.library
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN (SELECT l FROM docs.library l WHERE (l.slug = p_id OR l.id = p_id) AND l.tenant_id = current_setting('app.tenant_id', true));
END;
$function$;
