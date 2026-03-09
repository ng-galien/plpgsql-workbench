CREATE OR REPLACE FUNCTION docman_ut.test_peek()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_doc_id UUID;
  v_result JSONB;
BEGIN
  -- Setup
  INSERT INTO docstore.file (path, filename, extension, size_bytes, mime_type, content_hash)
  VALUES ('/tmp/test/peek-test.pdf', 'peek-test.pdf', '.pdf', 500, 'application/pdf', 'peek1')
  ON CONFLICT DO NOTHING;
  INSERT INTO docman.document (file_path, doc_type, document_date, summary)
  VALUES ('/tmp/test/peek-test.pdf', 'facture', '2024-05-01', 'Test peek summary')
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_doc_id;

  IF v_doc_id IS NULL THEN
    SELECT id INTO v_doc_id FROM docman.document WHERE file_path = '/tmp/test/peek-test.pdf';
  END IF;

  -- Add classification data
  PERFORM docman.tag(v_doc_id, 'Comptabilite', 'category', NULL, 0.5);
  PERFORM docman.link(v_doc_id, 'fournisseur', 'EDF', 'emetteur', 0.5);

  -- Test: peek returns document metadata
  SELECT docman.peek(v_doc_id) INTO v_result;
  RETURN NEXT ok(v_result->>'filename' = 'peek-test.pdf', 'peek returns filename');
  RETURN NEXT ok(v_result->>'doc_type' = 'facture', 'peek returns doc_type');
  RETURN NEXT ok(v_result->>'summary' = 'Test peek summary', 'peek returns summary');

  -- Test: peek returns labels
  RETURN NEXT ok(jsonb_array_length(v_result->'labels') = 1, 'peek returns labels');
  RETURN NEXT ok((v_result->'labels'->0->>'name') = 'Comptabilite', 'peek label has correct name');
  RETURN NEXT ok((v_result->'labels'->0->>'confidence')::REAL = 0.5, 'peek label has confidence');

  -- Test: peek returns entities
  RETURN NEXT ok(jsonb_array_length(v_result->'entities') = 1, 'peek returns entities');
  RETURN NEXT ok((v_result->'entities'->0->>'name') = 'EDF', 'peek entity has correct name');

  -- Test: peek on non-existent document
  SELECT docman.peek('00000000-0000-0000-0000-000000000000') INTO v_result;
  RETURN NEXT ok(v_result->>'error' = 'document not found', 'peek returns error for unknown doc');

  -- Cleanup
  DELETE FROM docman.document_label WHERE document_id = v_doc_id;
  DELETE FROM docman.document_entity WHERE document_id = v_doc_id;
  DELETE FROM docman.document WHERE id = v_doc_id;
  DELETE FROM docman.label WHERE name = 'Comptabilite';
  DELETE FROM docman.entity WHERE name = 'EDF';
  DELETE FROM docstore.file WHERE path = '/tmp/test/peek-test.pdf';
END;
$function$;
