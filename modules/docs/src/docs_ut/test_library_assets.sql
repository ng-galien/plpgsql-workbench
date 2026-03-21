CREATE OR REPLACE FUNCTION docs_ut.test_library_assets()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_lib docs.library;
  v_asset_id uuid;
  v_cnt int;
  v_role text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.library WHERE tenant_id = 'test';

  v_lib := docs.library_create(jsonb_populate_record(NULL::docs.library, '{"name":"Test Lib"}'::jsonb));

  -- Get a real asset
  SELECT id INTO v_asset_id FROM asset.asset LIMIT 1;
  IF v_asset_id IS NULL THEN
    RETURN NEXT skip('no assets in database');
    DELETE FROM docs.library WHERE tenant_id = 'test';
    RETURN;
  END IF;

  -- Add asset
  PERFORM docs.library_add_asset(v_lib.id, v_asset_id, 'hero', 'Photo principale pleine largeur');
  SELECT count(*)::int INTO v_cnt FROM docs.library_asset WHERE library_id = v_lib.id;
  RETURN NEXT is(v_cnt, 1, 'asset added');

  SELECT role INTO v_role FROM docs.library_asset WHERE library_id = v_lib.id AND asset_id = v_asset_id;
  RETURN NEXT is(v_role, 'hero', 'role stored');

  -- Upsert role
  PERFORM docs.library_add_asset(v_lib.id, v_asset_id, 'background', 'Fond de page');
  SELECT role INTO v_role FROM docs.library_asset WHERE library_id = v_lib.id AND asset_id = v_asset_id;
  RETURN NEXT is(v_role, 'background', 'role updated via upsert');

  -- Remove
  RETURN NEXT ok(docs.library_remove_asset(v_lib.id, v_asset_id), 'remove returns true');
  SELECT count(*)::int INTO v_cnt FROM docs.library_asset WHERE library_id = v_lib.id;
  RETURN NEXT is(v_cnt, 0, 'asset removed');

  -- Remove nonexistent
  RETURN NEXT ok(NOT docs.library_remove_asset(v_lib.id, v_asset_id), 'remove nonexistent returns false');

  DELETE FROM docs.library WHERE tenant_id = 'test';
END;
$function$;
