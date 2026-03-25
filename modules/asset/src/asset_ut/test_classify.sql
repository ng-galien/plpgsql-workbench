CREATE OR REPLACE FUNCTION asset_ut.test_classify()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id     UUID;
  v_result JSONB;
  v_asset  RECORD;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  INSERT INTO asset.asset (path, filename, mime_type)
  VALUES ('uploads/test.jpg', 'test.jpg', 'image/jpeg')
  RETURNING id INTO v_id;

  SELECT * INTO v_asset FROM asset.asset WHERE id = v_id;
  RETURN NEXT ok(v_asset.status = 'to_classify', 'initial status is to_classify');
  RETURN NEXT ok(v_asset.classified_at IS NULL, 'classified_at is null initially');

  v_result := asset.classify(
    p_id          := v_id,
    p_title       := 'Concert jazz en plein air',
    p_description := 'Photo d''un concert de jazz dans un parc municipal',
    p_tags        := ARRAY['jazz', 'concert', 'musique', 'plein air'],
    p_width       := 1920,
    p_height      := 1080,
    p_orientation := 'landscape',
    p_season      := 'summer',
    p_credit      := 'Photo Studio',
    p_usage_hint  := 'web banner',
    p_colors      := ARRAY['#1a2b3c', '#d4e5f6']
  );

  RETURN NEXT ok(v_result->>'status' = 'classified', 'classify returns classified status');

  SELECT * INTO v_asset FROM asset.asset WHERE id = v_id;
  RETURN NEXT ok(v_asset.status = 'classified', 'status updated to classified');
  RETURN NEXT ok(v_asset.classified_at IS NOT NULL, 'classified_at is set');
  RETURN NEXT ok(v_asset.title = 'Concert jazz en plein air', 'title is set');
  RETURN NEXT ok(cardinality(v_asset.tags) = 4, 'tags array has 4 elements');
  RETURN NEXT ok(v_asset.width = 1920, 'width is set');
  RETURN NEXT ok(v_asset.orientation = 'landscape', 'orientation is set');
  RETURN NEXT ok(v_asset.usage_hint = 'web banner', 'usage_hint is set');

  DELETE FROM asset.asset WHERE id = v_id;
END;
$function$;
