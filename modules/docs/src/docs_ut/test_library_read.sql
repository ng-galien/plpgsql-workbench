CREATE OR REPLACE FUNCTION docs_ut.test_library_read()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_lib_id text;
  v_asset_id uuid;
  v_result jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.library WHERE tenant_id = 'test';

  v_lib_id := docs.library_create('Load Test', 'Test library');

  SELECT id INTO v_asset_id FROM asset.asset LIMIT 1;
  IF v_asset_id IS NULL THEN
    RETURN NEXT skip('no assets in database');
    DELETE FROM docs.library WHERE tenant_id = 'test';
    RETURN;
  END IF;

  PERFORM docs.library_add_asset(v_lib_id, v_asset_id, 'logo', 'Logo entreprise');

  v_result := docs.library_read(v_lib_id);

  RETURN NEXT ok(v_result IS NOT NULL, 'library_read returns data');
  RETURN NEXT is(v_result->>'name', 'Load Test', 'name in result');
  RETURN NEXT is(jsonb_array_length(v_result->'assets'), 1, '1 asset');
  RETURN NEXT ok(v_result->'assets'->0->>'filename' IS NOT NULL, 'asset filename present');
  RETURN NEXT is(v_result->'assets'->0->>'role', 'logo', 'asset role present');

  -- Not found
  RETURN NEXT ok(docs.library_read('nonexistent') IS NULL, 'NULL for unknown library');

  DELETE FROM docs.library WHERE tenant_id = 'test';
END;
$function$;
