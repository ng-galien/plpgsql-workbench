CREATE OR REPLACE FUNCTION docs.document_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_result jsonb;
  v_status text;
  v_actions jsonb;
  v_page_count int;
BEGIN
  SELECT to_jsonb(d) || jsonb_build_object('charter_name', c.name, 'charter_slug', c.slug)
  INTO v_result
  FROM docs.document d
  LEFT JOIN docs.charter c ON c.id = d.charter_id
  WHERE (d.slug = p_id OR d.id = p_id) AND d.tenant_id = current_setting('app.tenant_id', true);

  IF v_result IS NULL THEN RETURN NULL; END IF;

  -- Stats
  SELECT count(*)::int INTO v_page_count FROM docs.page WHERE doc_id = v_result->>'id';
  v_result := v_result || jsonb_build_object('page_count', v_page_count);

  -- HATEOAS actions based on status
  v_status := v_result->>'status';
  v_actions := CASE v_status
    WHEN 'draft' THEN jsonb_build_array(
      jsonb_build_object('method', 'generate', 'uri', 'docs://document/' || (v_result->>'id') || '/generate'),
      jsonb_build_object('method', 'duplicate', 'uri', 'docs://document/' || (v_result->>'id') || '/duplicate'),
      jsonb_build_object('method', 'delete', 'uri', 'docs://document/' || (v_result->>'id') || '/delete')
    )
    WHEN 'generated' THEN jsonb_build_array(
      jsonb_build_object('method', 'sign', 'uri', 'docs://document/' || (v_result->>'id') || '/sign'),
      jsonb_build_object('method', 'revert', 'uri', 'docs://document/' || (v_result->>'id') || '/revert'),
      jsonb_build_object('method', 'duplicate', 'uri', 'docs://document/' || (v_result->>'id') || '/duplicate')
    )
    WHEN 'signed' THEN jsonb_build_array(
      jsonb_build_object('method', 'archive', 'uri', 'docs://document/' || (v_result->>'id') || '/archive'),
      jsonb_build_object('method', 'duplicate', 'uri', 'docs://document/' || (v_result->>'id') || '/duplicate')
    )
    WHEN 'archived' THEN jsonb_build_array(
      jsonb_build_object('method', 'duplicate', 'uri', 'docs://document/' || (v_result->>'id') || '/duplicate')
    )
    ELSE '[]'::jsonb
  END;

  RETURN v_result || jsonb_build_object('actions', v_actions);
END;
$function$;
