CREATE OR REPLACE FUNCTION asset_ut.test_search()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id1    UUID;
  v_id2    UUID;
  v_id3    UUID;
  v_result JSONB;
  v_count  INT;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Setup: 3 assets
  INSERT INTO asset.asset (path, filename, mime_type, status, title, description, tags)
  VALUES ('uploads/a.jpg', 'a.jpg', 'image/jpeg', 'classified', 'Concert de jazz', 'Un concert en plein air', ARRAY['jazz','musique'])
  RETURNING id INTO v_id1;

  INSERT INTO asset.asset (path, filename, mime_type, status, title, description, tags)
  VALUES ('uploads/b.png', 'b.png', 'image/png', 'to_classify', NULL, NULL, '{}')
  RETURNING id INTO v_id2;

  INSERT INTO asset.asset (path, filename, mime_type, status, title, description, tags)
  VALUES ('uploads/c.jpg', 'c.jpg', 'image/jpeg', 'classified', 'Marché de Noël', 'Stand de vin chaud', ARRAY['marché','hiver'])
  RETURNING id INTO v_id3;

  -- Test: all assets
  v_result := asset.search('{}');
  v_count := jsonb_array_length(v_result->'rows');
  RETURN NEXT ok(v_count >= 3, 'search returns at least 3 assets');

  -- Test: status filter
  v_result := asset.search('{"p_status":"to_classify"}');
  v_count := jsonb_array_length(v_result->'rows');
  RETURN NEXT ok(v_count >= 1, 'status filter returns to_classify assets');

  -- Test: FTS
  v_result := asset.search('{"q":"jazz"}');
  v_count := jsonb_array_length(v_result->'rows');
  RETURN NEXT ok(v_count >= 1, 'FTS finds jazz');

  -- Test: tags overlap
  v_result := asset.search('{"p_tags":["hiver"]}');
  v_count := jsonb_array_length(v_result->'rows');
  RETURN NEXT ok(v_count >= 1, 'tags filter finds hiver');

  -- Test: mime filter
  v_result := asset.search('{"p_mime":"image/png"}');
  v_count := jsonb_array_length(v_result->'rows');
  RETURN NEXT ok(v_count >= 1, 'mime filter finds png');

  -- Test: has_more pagination
  v_result := asset.search('{"_size":1}');
  RETURN NEXT ok((v_result->>'has_more')::boolean, 'has_more is true with size=1');

  -- Cleanup
  DELETE FROM asset.asset WHERE id IN (v_id1, v_id2, v_id3);
END;
$function$;
