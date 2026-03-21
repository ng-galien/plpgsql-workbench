CREATE OR REPLACE FUNCTION document_ut.test_library_delete()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_lib_id text;
  v_asset_id uuid;
  v_doc_id text;
  v_cnt int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM document.document WHERE tenant_id = 'test';
  DELETE FROM document.library WHERE tenant_id = 'test';

  v_lib_id := document.library_create('To Delete');

  -- Add asset if available
  SELECT id INTO v_asset_id FROM asset.asset LIMIT 1;
  IF v_asset_id IS NOT NULL THEN
    PERFORM document.library_add_asset(v_lib_id, v_asset_id, 'test');
  END IF;

  -- Link a document
  v_doc_id := document.doc_create('Linked Doc', p_library_id := v_lib_id);

  RETURN NEXT ok(document.library_delete('To Delete'), 'delete returns true');

  SELECT count(*)::int INTO v_cnt FROM document.library WHERE id = v_lib_id;
  RETURN NEXT is(v_cnt, 0, 'library removed');

  -- Document still exists, library_id NULL
  RETURN NEXT ok(
    (SELECT library_id IS NULL FROM document.document WHERE id = v_doc_id),
    'document library_id set to NULL'
  );

  RETURN NEXT ok(NOT document.library_delete('Nonexistent'), 'delete unknown returns false');

  DELETE FROM document.document WHERE tenant_id = 'test';
END;
$function$;
