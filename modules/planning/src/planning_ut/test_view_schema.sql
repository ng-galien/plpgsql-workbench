CREATE OR REPLACE FUNCTION planning_ut.test_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEXT ok(
    (SELECT (pgv.check_view('planning', 'worker'))->>'valid' = 'true'),
    'worker_view() passes JSON Schema validation'
  );
  RETURN NEXT ok(
    (SELECT (pgv.check_view('planning', 'event'))->>'valid' = 'true'),
    'event_view() passes JSON Schema validation'
  );
END;
$function$;
