CREATE OR REPLACE FUNCTION quote_ut.test_devis_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_check jsonb;
BEGIN
  v_check := pgv.check_view('quote', 'devis');
  RETURN NEXT ok((v_check->>'valid')::boolean, 'devis_view() passes JSON Schema validation');
  RETURN NEXT is(v_check->>'uri', 'quote://devis', 'devis_view() uri is quote://devis');
END;
$function$;
