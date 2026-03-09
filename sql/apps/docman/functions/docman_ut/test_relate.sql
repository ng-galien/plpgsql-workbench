CREATE OR REPLACE FUNCTION docman_ut.test_relate()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_doc1 UUID;
  v_doc2 UUID;
BEGIN
  -- Setup: two documents
  INSERT INTO docstore.file (path, filename, extension, size_bytes, mime_type, content_hash)
  VALUES ('/tmp/test/devis.pdf', 'devis.pdf', '.pdf', 100, 'application/pdf', 'rel1'),
         ('/tmp/test/facture.pdf', 'facture.pdf', '.pdf', 200, 'application/pdf', 'rel2')
  ON CONFLICT DO NOTHING;

  INSERT INTO docman.document (file_path) VALUES ('/tmp/test/devis.pdf')
  ON CONFLICT DO NOTHING RETURNING id INTO v_doc1;
  INSERT INTO docman.document (file_path) VALUES ('/tmp/test/facture.pdf')
  ON CONFLICT DO NOTHING RETURNING id INTO v_doc2;

  IF v_doc1 IS NULL THEN SELECT id INTO v_doc1 FROM docman.document WHERE file_path = '/tmp/test/devis.pdf'; END IF;
  IF v_doc2 IS NULL THEN SELECT id INTO v_doc2 FROM docman.document WHERE file_path = '/tmp/test/facture.pdf'; END IF;

  -- Test: relate
  PERFORM docman.relate(v_doc1, v_doc2, 'follows', 0.9);
  RETURN NEXT ok(
    EXISTS(SELECT 1 FROM docman.document_relation WHERE source_id = v_doc1 AND target_id = v_doc2 AND kind = 'follows'),
    'relate creates relation'
  );
  RETURN NEXT is(
    (SELECT confidence FROM docman.document_relation WHERE source_id = v_doc1 AND target_id = v_doc2),
    0.9::REAL,
    'relate stores confidence'
  );

  -- Test: relations returns both directions
  RETURN NEXT ok(
    (SELECT count(*) FROM docman.relations(v_doc1)) = 1,
    'relations returns outgoing from source'
  );
  RETURN NEXT ok(
    (SELECT direction FROM docman.relations(v_doc2)) = 'incoming',
    'relations returns incoming on target'
  );

  -- Test: unrelate
  PERFORM docman.unrelate(v_doc1, v_doc2, 'follows');
  RETURN NEXT ok(
    NOT EXISTS(SELECT 1 FROM docman.document_relation WHERE source_id = v_doc1 AND target_id = v_doc2),
    'unrelate removes relation'
  );

  -- Cleanup
  DELETE FROM docman.document WHERE id IN (v_doc1, v_doc2);
  DELETE FROM docstore.file WHERE path IN ('/tmp/test/devis.pdf', '/tmp/test/facture.pdf');
END;
$function$;
