CREATE OR REPLACE FUNCTION pgv_ut.test_fts()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  -- Stemming: "poutre" matches "poutres", "Poutre"
  v_result := pgv_qa.data_products('{"q":"poutre"}'::jsonb);
  RETURN NEXT ok((v_result->>'total')::int > 0, 'poutre matches Poutre (case-insensitive)');
  RETURN NEXT ok(v_result->'rows'->0->>1 LIKE '%outre%', 'poutre result contains poutre in name');

  -- Accent: "chene" matches "chêne"
  v_result := pgv_qa.data_products('{"q":"chene"}'::jsonb);
  RETURN NEXT ok((v_result->>'total')::int >= 2, 'chene matches chêne (accent-insensitive)');

  -- Multi-word: "coffrage beton" matches planche de coffrage
  v_result := pgv_qa.data_products('{"q":"coffrage beton"}'::jsonb);
  RETURN NEXT ok((v_result->>'total')::int > 0, 'coffrage beton matches multi-word');

  -- No match
  v_result := pgv_qa.data_products('{"q":"xyz123"}'::jsonb);
  RETURN NEXT is((v_result->>'total')::int, 0, 'xyz123 no match → total 0');
  RETURN NEXT is(v_result->'rows', '[]'::jsonb, 'xyz123 no match → rows empty');

  -- Pagination: page 1, size 5 on 20 products
  v_result := pgv_qa.data_products('{"_page":1,"_size":5}'::jsonb);
  RETURN NEXT is((v_result->>'total')::int, 20, 'pagination total = 20');
  RETURN NEXT is(jsonb_array_length(v_result->'rows'), 5, 'pagination page 1 returns 5 rows');
  RETURN NEXT is((v_result->>'page')::int, 1, 'pagination page = 1');
  RETURN NEXT is((v_result->>'size')::int, 5, 'pagination size = 5');

  -- Filter: category = bois
  v_result := pgv_qa.data_products('{"p_category":"bois"}'::jsonb);
  RETURN NEXT ok((v_result->>'total')::int >= 5, 'category filter bois returns >= 5');

  -- Filter + FTS combined
  v_result := pgv_qa.data_products('{"p_category":"quincaillerie","q":"vis"}'::jsonb);
  RETURN NEXT ok((v_result->>'total')::int >= 1, 'category + FTS combined works');
END;
$function$;
