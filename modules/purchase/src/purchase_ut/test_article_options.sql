CREATE OR REPLACE FUNCTION purchase_ut.test_article_options()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  v_result := purchase.article_options();
  RETURN NEXT ok(jsonb_typeof(v_result) = 'array', 'article_options() returns array');

  v_result := purchase.article_options('xyz_no_match');
  RETURN NEXT ok(jsonb_typeof(v_result) = 'array', 'article_options(search) returns array');
END;
$function$;
