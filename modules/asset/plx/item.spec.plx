test "classify lifecycle":
  c := asset.asset_create({path: 'uploads/test.jpg', filename: 'test.jpg', mime_type: 'image/jpeg'})
  asset_id := (c->>'id')::int

  row := select * from asset.asset where id = asset_id
  assert row.status = 'to_classify'
  assert row.classified_at is null

  result := asset.classify(
    p_id := asset_id,
    p_title := 'Concert jazz en plein air',
    p_description := 'Photo de concert jazz',
    p_tags := '{jazz,concert,musique,plein air}'::text[],
    p_width := 1920,
    p_height := 1080,
    p_orientation := 'landscape',
    p_season := 'summer',
    p_credit := 'Photo Studio',
    p_usage_hint := 'web banner',
    p_colors := '{#1a2b3c,#d4e5f6}'::text[]
  )
  assert result->>'status' = 'classified'

  row2 := select * from asset.asset where id = asset_id
  assert row2.status = 'classified'
  assert row2.classified_at is not null
  assert row2.title = 'Concert jazz en plein air'
  assert cardinality(row2.tags) = 4
  assert row2.orientation = 'landscape'

  asset.asset_delete(c->>'id')

test "data_assets format and pagination":
  a1 := asset.asset_create({path: 'uploads/d1.jpg', filename: 'd1.jpg', mime_type: 'image/jpeg', title: 'Photo test 1'})
  a2 := asset.asset_create({path: 'uploads/d2.jpg', filename: 'd2.jpg', mime_type: 'image/jpeg'})

  result := asset.data_assets('{}'::jsonb)
  assert result ? 'rows'
  assert result ? 'has_more'
  assert jsonb_array_length(result->'rows') >= 2

  row := (result->'rows')->0
  assert jsonb_array_length(row) = 7

  filtered := asset.data_assets('{"_size":1}'::jsonb)
  assert (filtered->>'has_more')::boolean = true

  asset.asset_delete(a1->>'id')
  asset.asset_delete(a2->>'id')

test "search with FTS and filters":
  s1 := asset.asset_create({path: 'uploads/s1.jpg', filename: 's1.jpg', mime_type: 'image/jpeg', title: 'Concert de jazz'})
  s2 := asset.asset_create({path: 'uploads/s2.png', filename: 's2.png', mime_type: 'image/png'})

  all := asset.search('{}'::jsonb)
  assert jsonb_array_length(all->'rows') >= 2

  fts := asset.search('{"q":"jazz"}'::jsonb)
  assert jsonb_array_length(fts->'rows') >= 1

  mime := asset.search('{"p_mime":"image/png"}'::jsonb)
  assert jsonb_array_length(mime->'rows') >= 1

  paged := asset.search('{"_size":1}'::jsonb)
  assert (paged->>'has_more')::boolean = true

  asset.asset_delete(s1->>'id')
  asset.asset_delete(s2->>'id')

test "asset crud":
  c := asset.asset_create({path: 'uploads/crud.jpg', filename: 'crud.jpg'})
  assert c->>'filename' = 'crud.jpg'
  assert c->>'status' = 'to_classify'

  r := asset.asset_read(c->>'id')
  assert r->>'filename' = 'crud.jpg'
  assert r->>'actions' != 'null'

  d := asset.asset_delete(c->>'id')
  assert d->>'filename' = 'crud.jpg'
