CREATE OR REPLACE FUNCTION query_ut.test_rsql()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
BEGIN
  -- Simple equality (text)
  v_result := query.rsql_to_where('subject==hello', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'subject = ''hello''', 'eq text: subject==hello');

  -- Equality (numeric) — no quotes
  v_result := query.rsql_to_where('id==42', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'id = 42', 'eq numeric: id==42');

  -- Not equal
  v_result := query.rsql_to_where('status!=resolved', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'status != ''resolved''', 'neq: status!=resolved');

  -- Greater than (numeric)
  v_result := query.rsql_to_where('id>100', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'id > 100', 'gt numeric: id>100');

  -- Less than equal (numeric)
  v_result := query.rsql_to_where('id<=5', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'id <= 5', 'lte numeric: id<=5');

  -- AND (;)
  v_result := query.rsql_to_where('from_module==crm;status==acknowledged', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'from_module = ''crm'' AND status = ''acknowledged''', 'AND: ;');

  -- OR (,)
  v_result := query.rsql_to_where('id>=50,from_module==crm', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, '(id >= 50) OR (from_module = ''crm'')', 'OR: ,');

  -- IN
  v_result := query.rsql_to_where('status=in=(new,acknowledged)', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'status IN (''new'', ''acknowledged'')', 'in: =in=()');

  -- NOT IN
  v_result := query.rsql_to_where('status=out=(resolved,failed)', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'status NOT IN (''resolved'', ''failed'')', 'out: =out=()');

  -- LIKE with wildcard
  v_result := query.rsql_to_where('subject=like=*task*', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'subject LIKE ''%task%''', 'like: *→%');

  -- ILIKE
  v_result := query.rsql_to_where('subject=ilike=*TASK*', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'subject ILIKE ''%TASK%''', 'ilike: case-insensitive');

  -- IS NULL
  v_result := query.rsql_to_where('reply_to=isnull=true', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'reply_to IS NULL', 'isnull=true → IS NULL');

  -- IS NOT NULL (via isnull=false)
  v_result := query.rsql_to_where('reply_to=isnull=false', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'reply_to IS NOT NULL', 'isnull=false → IS NOT NULL');

  -- NOTNULL
  v_result := query.rsql_to_where('subject=notnull=true', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'subject IS NOT NULL', 'notnull=true → IS NOT NULL');

  -- BETWEEN (numeric)
  v_result := query.rsql_to_where('id=bt=(10,50)', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'id BETWEEN 10 AND 50', 'between numeric');

  -- Combined IN + LIKE with AND
  v_result := query.rsql_to_where('status=in=(new,acknowledged);subject=like=*task*', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'status IN (''new'', ''acknowledged'') AND subject LIKE ''%task%''', 'combined in+like');

  -- Empty filter → true
  v_result := query.rsql_to_where('', 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'true', 'empty filter → true');

  -- NULL filter → true
  v_result := query.rsql_to_where(NULL, 'workbench', 'agent_message');
  RETURN NEXT is(v_result, 'true', 'null filter → true');

  -- Invalid column → RAISE
  BEGIN
    v_result := query.rsql_to_where('fakecol==test', 'workbench', 'agent_message');
    RETURN NEXT fail('invalid column should raise');
  EXCEPTION WHEN OTHERS THEN
    RETURN NEXT ok(SQLERRM LIKE '%does not exist%', 'invalid column raises exception');
  END;

  -- Injection: quotes escaped
  v_result := query.rsql_to_where('subject==O''Reilly', 'workbench', 'agent_message');
  RETURN NEXT ok(v_result LIKE '%O''''Reilly%', 'injection: quotes escaped');

  -- rsql_validate: valid
  RETURN NEXT is(query.rsql_validate('name==test;price>10'), true, 'validate: valid');

  -- rsql_validate: invalid
  RETURN NEXT is(query.rsql_validate('not a filter'), false, 'validate: invalid');

  -- rsql_validate: empty
  RETURN NEXT is(query.rsql_validate(''), true, 'validate: empty is valid');
END;
$function$;
