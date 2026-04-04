CREATE OR REPLACE FUNCTION crm_ut.test_client_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(
    (SELECT (pgv.check_view('crm', 'client'))->>'valid' = 'true'),
    'client_view() passes JSON Schema validation'
  );
END;
$function$;
