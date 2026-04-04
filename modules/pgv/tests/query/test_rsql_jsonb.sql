CREATE OR REPLACE FUNCTION pgv_ut.test_rsql_jsonb()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
BEGIN
  -- Simple jsonb key
  v_result := pgv.rsql_to_where('color_extra.ocean==#2E7D9B', 'docs', 'charte');
  RETURN NEXT is(v_result, 'color_extra->>''ocean'' = ''#2E7D9B''', 'jsonb simple: color_extra.ocean');

  -- LIKE on jsonb
  v_result := pgv.rsql_to_where('rules.layout=like=*marge*', 'docs', 'charte');
  RETURN NEXT is(v_result, 'rules->>''layout'' LIKE ''%marge%''', 'jsonb like: rules.layout');

  -- IS NULL on jsonb key
  v_result := pgv.rsql_to_where('color_extra.ocean=isnull=true', 'docs', 'charte');
  RETURN NEXT is(v_result, 'color_extra->>''ocean'' IS NULL', 'jsonb isnull');

  -- Nested path with array index
  v_result := pgv.rsql_to_where('voice_examples.0.good==test', 'docs', 'charte');
  RETURN NEXT is(v_result, 'voice_examples->0->>''good'' = ''test''', 'jsonb nested: array index + key');

  -- Non-jsonb column with no dot = normal column (regression)
  v_result := pgv.rsql_to_where('name==ocean', 'docs', 'charte');
  RETURN NEXT is(v_result, 'name = ''ocean''', 'non-jsonb stays simple');
END;
$function$;
