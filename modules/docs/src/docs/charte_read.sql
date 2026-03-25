CREATE OR REPLACE FUNCTION docs.charte_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
  v_doc_count int;
BEGIN
  SELECT to_jsonb(c) INTO v_result
  FROM docs.charte c WHERE (c.slug = p_id OR c.id = p_id) AND c.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN RETURN NULL; END IF;

  SELECT count(*)::int INTO v_doc_count FROM docs.document WHERE charte_id = v_result->>'id' AND tenant_id = current_setting('app.tenant_id', true);

  RETURN v_result || jsonb_build_object(
    'document_count', v_doc_count,
    'actions', jsonb_build_array(
      jsonb_build_object('method', 'update', 'uri', 'docs://charte/' || (v_result->>'id') || '/update'),
      jsonb_build_object('method', 'duplicate', 'uri', 'docs://charte/' || (v_result->>'id') || '/duplicate'),
      jsonb_build_object('method', 'delete', 'uri', 'docs://charte/' || (v_result->>'id') || '/delete')
    )
  );
END;
$function$;
