CREATE OR REPLACE FUNCTION pgv_ut.test_rsql()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
BEGIN
  -- Simple equality (text)
  v_result := pgv.rsql_to_where('name==ocean', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'name = ''ocean''', 'eq text: name==ocean');

  -- Equality (numeric) — no quotes
  v_result := pgv.rsql_to_where('price==42', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'price = 42', 'eq numeric: price==42');

  -- Not equal
  v_result := pgv.rsql_to_where('status!=draft', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'status != ''draft''', 'neq: status!=draft');

  -- Greater than (numeric)
  v_result := pgv.rsql_to_where('price>100', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'price > 100', 'gt numeric: price>100');

  -- Less than equal (numeric)
  v_result := pgv.rsql_to_where('id<=5', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'id <= 5', 'lte numeric: id<=5');

  -- AND (;)
  v_result := pgv.rsql_to_where('category==bois;status==actif', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'category = ''bois'' AND status = ''actif''', 'AND: ;');

  -- OR (,)
  v_result := pgv.rsql_to_where('price>=50,category==bois', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, '(price >= 50) OR (category = ''bois'')', 'OR: ,');

  -- IN
  v_result := pgv.rsql_to_where('status=in=(draft,actif)', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'status IN (''draft'', ''actif'')', 'in: =in=()');

  -- NOT IN
  v_result := pgv.rsql_to_where('category=out=(test,tmp)', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'category NOT IN (''test'', ''tmp'')', 'out: =out=()');

  -- LIKE with wildcard
  v_result := pgv.rsql_to_where('name=like=*poutre*', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'name LIKE ''%poutre%''', 'like: *→%');

  -- ILIKE
  v_result := pgv.rsql_to_where('name=ilike=*OCEAN*', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'name ILIKE ''%OCEAN%''', 'ilike: case-insensitive');

  -- IS NULL
  v_result := pgv.rsql_to_where('description=isnull=true', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'description IS NULL', 'isnull=true → IS NULL');

  -- IS NOT NULL (via isnull=false)
  v_result := pgv.rsql_to_where('description=isnull=false', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'description IS NOT NULL', 'isnull=false → IS NOT NULL');

  -- NOTNULL
  v_result := pgv.rsql_to_where('name=notnull=true', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'name IS NOT NULL', 'notnull=true → IS NOT NULL');

  -- BETWEEN (numeric)
  v_result := pgv.rsql_to_where('price=bt=(10,50)', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'price BETWEEN 10 AND 50', 'between numeric');

  -- Combined IN + LIKE with AND
  v_result := pgv.rsql_to_where('status=in=(draft,actif);name=like=*poutre*', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'status IN (''draft'', ''actif'') AND name LIKE ''%poutre%''', 'combined in+like');

  -- Empty filter → true
  v_result := pgv.rsql_to_where('', 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'true', 'empty filter → true');

  -- NULL filter → true
  v_result := pgv.rsql_to_where(NULL, 'pgv_qa', 'product');
  RETURN NEXT is(v_result, 'true', 'null filter → true');

  -- Invalid column → RAISE
  BEGIN
    v_result := pgv.rsql_to_where('fakecol==test', 'pgv_qa', 'product');
    RETURN NEXT fail('invalid column should raise');
  EXCEPTION WHEN OTHERS THEN
    RETURN NEXT ok(SQLERRM LIKE '%does not exist%', 'invalid column raises exception');
  END;

  -- Injection: quotes escaped
  v_result := pgv.rsql_to_where('name==O''Reilly', 'pgv_qa', 'product');
  RETURN NEXT ok(v_result LIKE '%O''''Reilly%', 'injection: quotes escaped');

  -- rsql_validate: valid
  RETURN NEXT is(pgv.rsql_validate('name==test;price>10'), true, 'validate: valid');

  -- rsql_validate: invalid
  RETURN NEXT is(pgv.rsql_validate('not a filter'), false, 'validate: invalid');

  -- rsql_validate: empty
  RETURN NEXT is(pgv.rsql_validate(''), true, 'validate: empty is valid');
END;
$function$;
