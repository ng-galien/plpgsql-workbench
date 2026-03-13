CREATE OR REPLACE FUNCTION pgv_ut.test_html_audit()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
BEGIN
  -- 1. Returns text
  RETURN NEXT ok(pg_typeof(pgv.html_audit('pgv'))::text = 'text', 'returns text');

  -- 2. Always returns a report (even for unknown schema — shows "clean")
  v_result := pgv.html_audit('nonexistent_schema_xyz');
  RETURN NEXT ok(v_result LIKE '%HTML audit%', 'report header for unknown schema');
  RETURN NEXT ok(v_result LIKE '%clean%', 'clean badge for unknown schema');

  -- 3. pgv schema runs without error
  v_result := pgv.html_audit('pgv');
  RETURN NEXT ok(v_result LIKE '%HTML audit%', 'report header for pgv');

  -- 4. Result contains findings for schemas with raw HTML
  v_result := pgv.html_audit('crm');
  IF v_result LIKE '%raw HTML%' THEN
    RETURN NEXT ok(v_result LIKE '%<md>%', 'markdown table present when findings');
  ELSE
    RETURN NEXT ok(v_result LIKE '%clean%', 'crm clean — shows clean badge');
  END IF;

  -- 5. pgv_ut schema shows clean (test functions, no get_/post_)
  v_result := pgv.html_audit('pgv_ut');
  RETURN NEXT ok(v_result LIKE '%clean%', 'test schema shows clean');

  RETURN;
END;
$function$;
