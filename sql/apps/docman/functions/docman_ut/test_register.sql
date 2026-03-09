CREATE OR REPLACE FUNCTION docman_ut.test_register()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result RECORD;
BEGIN
  -- Setup: insert a file in docstore
  INSERT INTO docstore.file (path, filename, extension, size_bytes, mime_type, content_hash)
  VALUES ('/tmp/test/facture.pdf', 'facture.pdf', '.pdf', 1024, 'application/pdf', 'abc123')
  ON CONFLICT DO NOTHING;

  -- Test: register should pick it up
  SELECT * INTO v_result FROM docman.register('/tmp/test/', 'filesystem');
  RETURN NEXT ok(v_result.registered >= 1, 'register creates documents from docstore.file');

  -- Test: second call should skip
  SELECT * INTO v_result FROM docman.register('/tmp/test/', 'filesystem');
  RETURN NEXT is(v_result.registered, 0, 'register skips already registered files');

  -- Cleanup
  DELETE FROM docman.document WHERE file_path = '/tmp/test/facture.pdf';
  DELETE FROM docstore.file WHERE path = '/tmp/test/facture.pdf';
END;
$function$;
