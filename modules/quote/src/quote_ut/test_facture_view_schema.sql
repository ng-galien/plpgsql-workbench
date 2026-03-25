CREATE OR REPLACE FUNCTION quote_ut.test_facture_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_check jsonb;
BEGIN
  v_check := pgv.check_view('quote', 'facture');
  RETURN NEXT ok((v_check->>'valid')::boolean, 'facture_view() passes JSON Schema validation');
  RETURN NEXT is(v_check->>'uri', 'quote://facture', 'facture_view() uri is quote://facture');
END;
$function$;
