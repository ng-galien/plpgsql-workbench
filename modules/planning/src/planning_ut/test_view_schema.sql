CREATE OR REPLACE FUNCTION planning_ut.test_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(
    (SELECT (pgv.check_view('planning', 'intervenant'))->>'valid' = 'true'),
    'intervenant_view() passes JSON Schema validation'
  );
  RETURN NEXT ok(
    (SELECT (pgv.check_view('planning', 'evenement'))->>'valid' = 'true'),
    'evenement_view() passes JSON Schema validation'
  );
END;
$function$;
