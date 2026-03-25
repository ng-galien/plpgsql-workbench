CREATE OR REPLACE FUNCTION catalog_ut.test_categorie_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_check jsonb;
BEGIN
  v_check := pgv.check_view('catalog', 'categorie');
  RETURN NEXT ok((v_check->>'valid')::boolean, 'categorie_view passes JSON Schema');
  RETURN NEXT is(v_check->>'uri', 'catalog://categorie', 'categorie_view URI correct');
END;
$function$;
