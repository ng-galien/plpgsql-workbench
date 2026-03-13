CREATE OR REPLACE FUNCTION pgv_ut.test_fts()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  -- Stemming: "poutre" matches "poutres", "Poutre"
  v_result := pgv_qa.data_products('{"q":"poutre"}'::jsonb);
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') > 0, 'poutre matches Poutre (case-insensitive)');
  RETURN NEXT ok(v_result->'rows'->0->>1 LIKE '%outre%', 'poutre result contains poutre in name');

  -- Accent: "chene" matches "chêne"
  v_result := pgv_qa.data_products('{"q":"chene"}'::jsonb);
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') >= 2, 'chene matches chêne (accent-insensitive)');

  -- Multi-word: "coffrage beton" matches planche de coffrage
  v_result := pgv_qa.data_products('{"q":"coffrage beton"}'::jsonb);
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') > 0, 'coffrage beton matches multi-word');

  -- No match
  v_result := pgv_qa.data_products('{"q":"xyz123"}'::jsonb);
  RETURN NEXT is(jsonb_array_length(v_result->'rows'), 0, 'xyz123 no match → rows empty');
  RETURN NEXT is((v_result->>'has_more')::bool, false, 'xyz123 no match → has_more false');

  -- Cursor pagination: offset 0, size 5 on 20 products
  v_result := pgv_qa.data_products('{"_offset":0,"_size":5}'::jsonb);
  RETURN NEXT is(jsonb_array_length(v_result->'rows'), 5, 'cursor offset=0 returns 5 rows');
  RETURN NEXT is((v_result->>'has_more')::bool, true, 'cursor offset=0 has_more = true (20 products)');

  -- Cursor pagination: last page
  v_result := pgv_qa.data_products('{"_offset":15,"_size":5}'::jsonb);
  RETURN NEXT is(jsonb_array_length(v_result->'rows'), 5, 'cursor offset=15 returns 5 rows');
  RETURN NEXT is((v_result->>'has_more')::bool, false, 'cursor offset=15 has_more = false (end)');

  -- Filter: category = bois
  v_result := pgv_qa.data_products('{"p_category":"bois"}'::jsonb);
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') >= 5, 'category filter bois returns >= 5');

  -- Filter + FTS combined
  v_result := pgv_qa.data_products('{"p_category":"quincaillerie","q":"vis"}'::jsonb);
  RETURN NEXT ok(jsonb_array_length(v_result->'rows') >= 1, 'category + FTS combined works');
END;
$function$;
