CREATE OR REPLACE FUNCTION docs_ut.test_library_delete()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_j jsonb;
  v_jd jsonb;
  v_asset_id uuid;
  v_cnt int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.document WHERE tenant_id = 'test';
  DELETE FROM docs.library WHERE tenant_id = 'test';

  v_j := docs.library_create(jsonb_populate_record(NULL::docs.library, '{"name":"To Delete"}'::jsonb));

  SELECT id INTO v_asset_id FROM asset.asset LIMIT 1;
  IF v_asset_id IS NOT NULL THEN
    PERFORM docs.library_add_asset(v_j->>'id', v_asset_id, 'test');
  END IF;

  v_jd := docs.document_create(jsonb_populate_record(NULL::docs.document, jsonb_build_object('name', 'Linked Doc', 'library_id', v_j->>'id')));

  RETURN NEXT ok(docs.library_delete(v_j->>'id') IS NOT NULL, 'delete returns true');

  SELECT count(*)::int INTO v_cnt FROM docs.library WHERE id = v_j->>'id';
  RETURN NEXT is(v_cnt, 0, 'library removed');

  RETURN NEXT ok(
    (SELECT library_id IS NULL FROM docs.document WHERE id = v_jd->>'id'),
    'document library_id set to NULL'
  );

  RETURN NEXT ok(docs.library_delete('nonexistent-id') IS NULL, 'delete unknown returns false');

  DELETE FROM docs.document WHERE tenant_id = 'test';
END;
$function$;
