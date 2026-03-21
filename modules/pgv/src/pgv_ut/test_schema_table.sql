CREATE OR REPLACE FUNCTION pgv_ut.test_schema_table()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_check jsonb;
BEGIN
  v_result := pgv.schema_table('document', 'document');

  RETURN NEXT is(v_result->>'schema', 'document', 'schema is document');
  RETURN NEXT is(v_result->>'table', 'document', 'table is document');
  RETURN NEXT ok(jsonb_array_length(v_result->'columns') > 10, 'has columns');

  -- CHECK constraints
  RETURN NEXT ok(jsonb_array_length(v_result->'check_constraints') > 0, 'has check constraints');
  SELECT item INTO v_check FROM jsonb_array_elements(v_result->'check_constraints') AS item
  WHERE item->>'definition' LIKE '%format%';
  RETURN NEXT ok(v_check IS NOT NULL, 'format check constraint found');
  RETURN NEXT ok(v_check->>'definition' LIKE '%A4%', 'format check includes A4');

  -- FK
  RETURN NEXT ok(jsonb_array_length(v_result->'foreign_keys') > 0, 'has foreign keys');

  -- Indexes
  RETURN NEXT ok(jsonb_array_length(v_result->'indexes') > 0, 'has indexes');

  -- RLS
  RETURN NEXT is((v_result->'rls'->>'enabled')::bool, true, 'RLS is enabled');
  RETURN NEXT ok(jsonb_array_length(v_result->'rls'->'policies') > 0, 'has RLS policies');
END;
$function$;
