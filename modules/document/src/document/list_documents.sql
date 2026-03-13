CREATE OR REPLACE FUNCTION document.list_documents(p_params jsonb DEFAULT '{}'::jsonb)
 RETURNS SETOF document.document
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_doc_type text := NULLIF(trim(COALESCE(p_params->>'doc_type', '')), '');
  v_status   text := NULLIF(trim(COALESCE(p_params->>'status', '')), '');
  v_module   text := NULLIF(trim(COALESCE(p_params->>'ref_module', '')), '');
BEGIN
  RETURN QUERY
  SELECT *
  FROM document.document
  WHERE tenant_id = current_setting('app.tenant_id', true)
    AND (v_doc_type IS NULL OR doc_type = v_doc_type)
    AND (v_status IS NULL OR status = v_status)
    AND (v_module IS NULL OR ref_module = v_module)
  ORDER BY created_at DESC;
END;
$function$;
