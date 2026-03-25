CREATE OR REPLACE FUNCTION stock_ut.test_article_options()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_row jsonb;
BEGIN
  INSERT INTO stock.article (reference, description, category, unit)
  VALUES ('TEST-OPT-001', 'Stainless screw 5x50', 'hardware', 'ea');

  v_result := stock.article_options('Stainless');
  RETURN NEXT ok(jsonb_array_length(v_result) >= 1, 'search returns at least 1 result');

  v_row := v_result->0;
  RETURN NEXT ok(v_row->>'value' IS NOT NULL, 'row has value');
  RETURN NEXT ok(v_row->>'label' = 'Stainless screw 5x50', 'label is designation');
  RETURN NEXT ok(v_row->>'detail' LIKE '%TEST-OPT-001%', 'detail contains reference');

  v_result := stock.article_options('TEST-OPT');
  RETURN NEXT ok(jsonb_array_length(v_result) >= 1, 'search by reference works');

  v_result := stock.article_options(NULL);
  RETURN NEXT ok(jsonb_array_length(v_result) >= 1, 'null search returns results');

  v_result := stock.article_options('zzz_no_match_zzz');
  RETURN NEXT is(v_result, '[]'::jsonb, 'no match returns empty array');

  DELETE FROM stock.article WHERE reference = 'TEST-OPT-001';
END;
$function$;
