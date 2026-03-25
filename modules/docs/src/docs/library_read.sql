CREATE OR REPLACE FUNCTION docs.library_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
  v_asset_count int;
  v_doc_count int;
BEGIN
  SELECT to_jsonb(l) INTO v_result
  FROM docs.library l WHERE (l.slug = p_id OR l.id = p_id) AND l.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN RETURN NULL; END IF;

  SELECT count(*)::int INTO v_asset_count FROM docs.library_asset WHERE library_id = v_result->>'id';
  SELECT count(*)::int INTO v_doc_count FROM docs.document WHERE library_id = v_result->>'id' AND tenant_id = current_setting('app.tenant_id', true);

  RETURN v_result || jsonb_build_object(
    'asset_count', v_asset_count,
    'document_count', v_doc_count,
    'actions', jsonb_build_array(
      jsonb_build_object('method', 'update', 'uri', 'docs://library/' || (v_result->>'id') || '/update'),
      jsonb_build_object('method', 'delete', 'uri', 'docs://library/' || (v_result->>'id') || '/delete')
    )
  );
END;
$function$;
