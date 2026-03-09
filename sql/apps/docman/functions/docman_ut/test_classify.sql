CREATE OR REPLACE FUNCTION docman_ut.test_classify()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_doc_id UUID;
  v_raised BOOLEAN;
BEGIN
  -- Setup
  INSERT INTO docstore.file (path, filename, extension, size_bytes, mime_type, content_hash)
  VALUES ('/tmp/test/contrat.pdf', 'contrat.pdf', '.pdf', 2048, 'application/pdf', 'def456')
  ON CONFLICT DO NOTHING;
  INSERT INTO docman.document (file_path, source)
  VALUES ('/tmp/test/contrat.pdf', 'filesystem')
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_doc_id;

  IF v_doc_id IS NULL THEN
    SELECT id INTO v_doc_id FROM docman.document WHERE file_path = '/tmp/test/contrat.pdf';
  END IF;

  -- Test classify sets all fields
  PERFORM docman.classify(v_doc_id, 'contrat', '2024-06-15', 'Contrat de prestation');
  RETURN NEXT ok(
    (SELECT doc_type = 'contrat' AND document_date = '2024-06-15' AND summary IS NOT NULL AND classified_at IS NOT NULL
     FROM docman.document WHERE id = v_doc_id),
    'classify sets type, date, summary, classified_at'
  );

  -- Test partial update (only summary)
  PERFORM docman.classify(v_doc_id, p_summary := 'Updated summary');
  RETURN NEXT is(
    (SELECT doc_type FROM docman.document WHERE id = v_doc_id),
    'contrat',
    'classify preserves existing fields when not provided'
  );

  -- Test classify on non-existent document raises exception
  v_raised := FALSE;
  BEGIN
    PERFORM docman.classify('00000000-0000-0000-0000-000000000000', 'test');
  EXCEPTION WHEN raise_exception THEN
    v_raised := TRUE;
  END;
  RETURN NEXT ok(v_raised, 'classify raises exception for unknown document');

  -- Cleanup
  DELETE FROM docman.document WHERE id = v_doc_id;
  DELETE FROM docstore.file WHERE path = '/tmp/test/contrat.pdf';
END;
$function$;
