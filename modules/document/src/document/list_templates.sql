CREATE OR REPLACE FUNCTION document.list_templates(p_doc_type text DEFAULT NULL::text)
 RETURNS SETOF document.template
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT *
  FROM document.template
  WHERE tenant_id = current_setting('app.tenant_id', true)
    AND (p_doc_type IS NULL OR doc_type = p_doc_type)
  ORDER BY doc_type, name;
END;
$function$;
