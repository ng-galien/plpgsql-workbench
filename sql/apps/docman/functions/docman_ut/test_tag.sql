CREATE OR REPLACE FUNCTION docman_ut.test_tag()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_doc_id UUID;
  v_label_id INT;
  v_label_id2 INT;
  v_child_id INT;
BEGIN
  -- Setup
  INSERT INTO docstore.file (path, filename, extension, size_bytes, mime_type, content_hash)
  VALUES ('/tmp/test/facture-edf.pdf', 'facture-edf.pdf', '.pdf', 512, 'application/pdf', 'tag123')
  ON CONFLICT DO NOTHING;
  INSERT INTO docman.document (file_path) VALUES ('/tmp/test/facture-edf.pdf')
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_doc_id;

  IF v_doc_id IS NULL THEN
    SELECT id INTO v_doc_id FROM docman.document WHERE file_path = '/tmp/test/facture-edf.pdf';
  END IF;

  -- Test: tag creates label on-the-fly
  SELECT docman.tag(v_doc_id, 'Factures', 'category') INTO v_label_id;
  RETURN NEXT ok(v_label_id IS NOT NULL, 'tag creates label on-the-fly');
  RETURN NEXT ok(
    EXISTS(SELECT 1 FROM docman.document_label WHERE document_id = v_doc_id AND label_id = v_label_id),
    'tag assigns label to document'
  );

  -- Test: tag with parent (covers parent resolution branch)
  SELECT docman.tag(v_doc_id, 'Fournisseurs', 'category', 'Factures') INTO v_child_id;
  RETURN NEXT ok(
    (SELECT parent_id FROM docman.label WHERE id = v_child_id) = v_label_id,
    'tag with parent creates nested category'
  );

  -- Test: tag with alias resolution
  INSERT INTO docman.label (name, kind, aliases) VALUES ('Urgent', 'tag', ARRAY['urgente', 'prioritaire'])
  ON CONFLICT DO NOTHING;
  SELECT docman.tag(v_doc_id, 'urgente', 'tag') INTO v_label_id2;
  RETURN NEXT is(
    (SELECT name FROM docman.label WHERE id = v_label_id2),
    'Urgent',
    'tag resolves aliases to canonical label'
  );

  -- Test: tag with name that matches nothing (no alias hit, creates new)
  PERFORM docman.tag(v_doc_id, 'BrandNewTag', 'tag');
  RETURN NEXT ok(
    EXISTS(SELECT 1 FROM docman.label WHERE name = 'BrandNewTag'),
    'tag creates new label when no alias matches'
  );

  -- Test: confidence is stored
  RETURN NEXT is(
    (SELECT confidence FROM docman.document_label WHERE document_id = v_doc_id AND label_id = v_label_id),
    1.0::REAL,
    'tag stores default confidence'
  );

  -- Test: untag removes assignment
  PERFORM docman.untag(v_doc_id, v_label_id);
  RETURN NEXT ok(
    NOT EXISTS(SELECT 1 FROM docman.document_label WHERE document_id = v_doc_id AND label_id = v_label_id),
    'untag removes label from document'
  );

  -- Cleanup
  DELETE FROM docman.document_label WHERE document_id = v_doc_id;
  DELETE FROM docman.document WHERE id = v_doc_id;
  DELETE FROM docman.label WHERE name IN ('Factures', 'Fournisseurs', 'Urgent', 'BrandNewTag');
  DELETE FROM docstore.file WHERE path = '/tmp/test/facture-edf.pdf';
END;
$function$;
