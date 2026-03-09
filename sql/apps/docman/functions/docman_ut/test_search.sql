CREATE OR REPLACE FUNCTION docman_ut.test_search()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_doc_id UUID;
  v_result JSONB;
BEGIN
  -- Setup
  INSERT INTO docstore.file (path, filename, extension, size_bytes, mime_type, content_hash)
  VALUES ('/tmp/test/search-test.pdf', 'search-test.pdf', '.pdf', 300, 'application/pdf', 'srch1')
  ON CONFLICT DO NOTHING;
  INSERT INTO docman.document (file_path, doc_type, document_date, summary)
  VALUES ('/tmp/test/search-test.pdf', 'facture', '2024-03-15', 'Facture electricite mars')
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_doc_id;

  IF v_doc_id IS NULL THEN
    SELECT id INTO v_doc_id FROM docman.document WHERE file_path = '/tmp/test/search-test.pdf';
  END IF;

  -- Test: search by doc_type
  SELECT docman.search('{"doc_type":"facture"}'::jsonb) INTO v_result;
  RETURN NEXT ok(jsonb_array_length(v_result) >= 1, 'search by doc_type returns results');

  -- Test: search by date range
  SELECT docman.search('{"after":"2024-01-01","before":"2024-12-31"}'::jsonb) INTO v_result;
  RETURN NEXT ok(jsonb_array_length(v_result) >= 1, 'search by date range returns results');

  -- Test: search by name pattern
  SELECT docman.search('{"name":"%search-test%"}'::jsonb) INTO v_result;
  RETURN NEXT ok(jsonb_array_length(v_result) >= 1, 'search by name pattern returns results');

  -- Test: full-text search on summary
  SELECT docman.search('{"q":"electricite"}'::jsonb) INTO v_result;
  RETURN NEXT ok(jsonb_array_length(v_result) >= 1, 'full-text search on summary works');

  -- Test: no results
  SELECT docman.search('{"doc_type":"inexistant"}'::jsonb) INTO v_result;
  RETURN NEXT is(jsonb_array_length(v_result), 0, 'search returns empty array when no match');

  -- Cleanup
  DELETE FROM docman.document WHERE id = v_doc_id;
  DELETE FROM docstore.file WHERE path = '/tmp/test/search-test.pdf';
END;
$function$;
