CREATE OR REPLACE FUNCTION crm_ut.test_interaction_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(
    (SELECT (pgv.check_view('crm', 'interaction'))->>'valid' = 'true'),
    'interaction_view() passes JSON Schema validation'
  );
END;
$function$;
