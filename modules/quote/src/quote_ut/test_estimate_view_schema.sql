CREATE OR REPLACE FUNCTION quote_ut.test_estimate_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_check jsonb;
BEGIN
  v_check := pgv.check_view('quote', 'estimate');
  RETURN NEXT ok((v_check->>'valid')::boolean, 'estimate_view() passes JSON Schema validation');
  RETURN NEXT is(v_check->>'uri', 'quote://estimate', 'estimate_view() uri is quote://estimate');
END;
$function$;
