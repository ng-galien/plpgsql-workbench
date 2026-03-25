CREATE OR REPLACE FUNCTION catalog_ut.test_category_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_check jsonb;
BEGIN
  v_check := pgv.check_view('catalog', 'category');
  RETURN NEXT ok((v_check->>'valid')::boolean, 'category_view passes JSON Schema');
  RETURN NEXT is(v_check->>'uri', 'catalog://category', 'category_view URI correct');
END;
$function$;
