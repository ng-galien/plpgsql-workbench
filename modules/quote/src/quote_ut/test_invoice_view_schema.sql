CREATE OR REPLACE FUNCTION quote_ut.test_invoice_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_check jsonb;
BEGIN
  v_check := pgv.check_view('quote', 'invoice');
  RETURN NEXT ok((v_check->>'valid')::boolean, 'invoice_view() passes JSON Schema validation');
  RETURN NEXT is(v_check->>'uri', 'quote://invoice', 'invoice_view() uri is quote://invoice');
END;
$function$;
