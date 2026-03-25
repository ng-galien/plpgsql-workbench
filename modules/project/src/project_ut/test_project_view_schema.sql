CREATE OR REPLACE FUNCTION project_ut.test_project_view_schema()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE v_check jsonb;
BEGIN
  v_check := pgv.check_view('project', 'project');
  RETURN NEXT is(v_check->>'valid', 'true', 'project_view passes JSON Schema');
  RETURN NEXT is(v_check->>'uri', 'project://project', 'project_view uri correct');
END;
$function$;
