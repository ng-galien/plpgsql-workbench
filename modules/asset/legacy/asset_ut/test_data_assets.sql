CREATE OR REPLACE FUNCTION asset_ut.test_data_assets()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id1    UUID;
  v_id2    UUID;
  v_result JSONB;
  v_row    JSONB;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Setup
  INSERT INTO asset.asset (path, filename, mime_type, title, status)
  VALUES ('uploads/d1.jpg', 'd1.jpg', 'image/jpeg', 'Photo test 1', 'classified')
  RETURNING id INTO v_id1;

  INSERT INTO asset.asset (path, filename, mime_type, status)
  VALUES ('uploads/d2.jpg', 'd2.jpg', 'image/jpeg', 'to_classify')
  RETURNING id INTO v_id2;

  -- Test: format
  v_result := asset.data_assets('{}');
  RETURN NEXT ok(v_result ? 'rows', 'result has rows key');
  RETURN NEXT ok(v_result ? 'has_more', 'result has has_more key');
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') >= 2, 'at least 2 rows returned');

  -- Test: row is array of 7 elements (id, filename, title, mime, status, tags, created)
  v_row := (v_result->'rows')->0;
  RETURN NEXT ok(jsonb_array_length(v_row) = 7, 'each row has 7 columns');

  -- Test: status filter
  v_result := asset.data_assets('{"p_status":"classified"}');
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') >= 1, 'status filter works');

  -- Test: pagination
  v_result := asset.data_assets('{"_size":1}');
  RETURN NEXT ok((v_result->>'has_more')::boolean, 'has_more true with size=1');

  v_result := asset.data_assets('{"_size":1,"_offset":1}');
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') >= 1, 'offset pagination works');

  -- Cleanup
  DELETE FROM asset.asset WHERE id IN (v_id1, v_id2);
END;
$function$;
