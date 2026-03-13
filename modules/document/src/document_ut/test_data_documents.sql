CREATE OR REPLACE FUNCTION document_ut.test_data_documents()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_tpl_id uuid;
  v_doc_id1 uuid;
  v_doc_id2 uuid;
  v_result jsonb;
  v_row jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Setup
  INSERT INTO document.template (name, doc_type) VALUES ('TPL test', 'facture')
  RETURNING id INTO v_tpl_id;

  INSERT INTO document.document (template_id, doc_type, title, status)
  VALUES (v_tpl_id, 'facture', 'Doc A', 'draft')
  RETURNING id INTO v_doc_id1;

  INSERT INTO document.document (template_id, doc_type, title, status)
  VALUES (v_tpl_id, 'devis', 'Doc B', 'generated')
  RETURNING id INTO v_doc_id2;

  -- Test: format
  v_result := document.data_documents('{}');
  RETURN NEXT ok(v_result ? 'rows', 'result has rows key');
  RETURN NEXT ok(v_result ? 'has_more', 'result has has_more key');
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') >= 2, 'at least 2 rows');

  -- Test: row has 7 columns (id, title, doc_type, ref_module, ref_id, status, created)
  v_row := (v_result->'rows')->0;
  RETURN NEXT ok(jsonb_array_length(v_row) = 7, 'each row has 7 columns');

  -- Test: status filter
  v_result := document.data_documents('{"p_status":"draft"}');
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') >= 1, 'status filter works');

  -- Test: doc_type filter
  v_result := document.data_documents('{"p_doc_type":"devis"}');
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') >= 1, 'doc_type filter works');

  -- Test: pagination
  v_result := document.data_documents('{"_size":1}');
  RETURN NEXT ok((v_result->>'has_more')::boolean, 'has_more true with size=1');

  v_result := document.data_documents('{"_size":1,"_offset":1}');
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') >= 1, 'offset pagination works');

  -- Cleanup
  DELETE FROM document.document WHERE id IN (v_doc_id1, v_doc_id2);
  DELETE FROM document.template WHERE id = v_tpl_id;
END;
$function$;
