CREATE OR REPLACE FUNCTION catalog_ut.test_article_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_check jsonb;
BEGIN
  v_check := pgv.check_view('catalog', 'article');
  RETURN NEXT ok((v_check->>'valid')::boolean, 'article_view passes JSON Schema');
  RETURN NEXT is(v_check->>'uri', 'catalog://article', 'article_view URI correct');
END;
$function$;
