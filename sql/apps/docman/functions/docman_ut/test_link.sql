CREATE OR REPLACE FUNCTION docman_ut.test_link()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_doc_id UUID;
  v_entity_id INT;
  v_entity_id2 INT;
BEGIN
  -- Setup
  INSERT INTO docstore.file (path, filename, extension, size_bytes, mime_type, content_hash)
  VALUES ('/tmp/test/facture-lm.pdf', 'facture-lm.pdf', '.pdf', 768, 'application/pdf', 'link123')
  ON CONFLICT DO NOTHING;
  INSERT INTO docman.document (file_path) VALUES ('/tmp/test/facture-lm.pdf')
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_doc_id;

  IF v_doc_id IS NULL THEN
    SELECT id INTO v_doc_id FROM docman.document WHERE file_path = '/tmp/test/facture-lm.pdf';
  END IF;

  -- Test: link creates entity on-the-fly
  SELECT docman.link(v_doc_id, 'fournisseur', 'Leroy Merlin', 'emetteur') INTO v_entity_id;
  RETURN NEXT ok(v_entity_id IS NOT NULL, 'link creates entity on-the-fly');
  RETURN NEXT ok(
    EXISTS(SELECT 1 FROM docman.document_entity WHERE document_id = v_doc_id AND entity_id = v_entity_id AND role = 'emetteur'),
    'link assigns entity with role'
  );

  -- Test: link with alias resolution
  UPDATE docman.entity SET aliases = ARRAY['LM', 'Leroy'] WHERE id = v_entity_id;
  SELECT docman.link(v_doc_id, 'fournisseur', 'LM', 'concerne') INTO v_entity_id2;
  RETURN NEXT is(v_entity_id2, v_entity_id, 'link resolves aliases to existing entity');

  -- Test: unlink removes assignment
  PERFORM docman.unlink(v_doc_id, v_entity_id, 'emetteur');
  RETURN NEXT ok(
    NOT EXISTS(SELECT 1 FROM docman.document_entity WHERE document_id = v_doc_id AND entity_id = v_entity_id AND role = 'emetteur'),
    'unlink removes entity link'
  );

  -- Cleanup
  DELETE FROM docman.document_entity WHERE document_id = v_doc_id;
  DELETE FROM docman.document WHERE id = v_doc_id;
  DELETE FROM docman.entity WHERE id = v_entity_id;
  DELETE FROM docstore.file WHERE path = '/tmp/test/facture-lm.pdf';
END;
$function$;
