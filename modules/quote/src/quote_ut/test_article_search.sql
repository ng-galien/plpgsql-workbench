CREATE OR REPLACE FUNCTION quote_ut.test_article_search()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_item jsonb;
BEGIN
  -- Test: returns jsonb array (not null)
  v_result := quote.article_search('');
  RETURN NEXT ok(v_result IS NOT NULL, 'search returns non-null');
  RETURN NEXT ok(jsonb_typeof(v_result) = 'array', 'search returns array');

  -- Test: with search filter
  v_result := quote.article_search('bois');
  RETURN NEXT ok(jsonb_typeof(v_result) = 'array', 'filtered search returns array');

  -- Test: items have required keys (value, label)
  IF jsonb_array_length(v_result) > 0 THEN
    v_item := v_result->0;
    RETURN NEXT ok(v_item ? 'value', 'item has value key');
    RETURN NEXT ok(v_item ? 'label', 'item has label key');
    RETURN NEXT ok(v_item ? 'detail', 'item has detail key');
  ELSE
    RETURN NEXT skip('no articles in stock, skipping structure checks');
    RETURN NEXT skip('no articles in stock');
    RETURN NEXT skip('no articles in stock');
  END IF;

  -- Test: nonsense search returns empty array
  v_result := quote.article_search('zzzzxyznonexistent');
  RETURN NEXT is(jsonb_array_length(v_result), 0, 'nonsense search returns empty');
END;
$function$;
