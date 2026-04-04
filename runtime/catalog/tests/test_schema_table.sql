CREATE OR REPLACE FUNCTION catalog_ut.test_schema_table()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_check jsonb;
BEGIN
  v_result := catalog.schema_table('workbench', 'agent_message');

  RETURN NEXT is(v_result->>'schema', 'workbench', 'schema is workbench');
  RETURN NEXT is(v_result->>'table', 'agent_message', 'table is agent_message');
  RETURN NEXT ok(jsonb_array_length(v_result->'columns') > 5, 'has columns');

  -- CHECK constraints (msg_type, priority, status)
  RETURN NEXT ok(jsonb_array_length(v_result->'check_constraints') > 0, 'has check constraints');
  SELECT item INTO v_check FROM jsonb_array_elements(v_result->'check_constraints') AS item
  WHERE item->>'definition' LIKE '%msg_type%';
  RETURN NEXT ok(v_check IS NOT NULL, 'msg_type check constraint found');
  RETURN NEXT ok(v_check->>'definition' LIKE '%task%', 'msg_type check includes task');

  -- Indexes
  RETURN NEXT ok(jsonb_array_length(v_result->'indexes') >= 0, 'indexes is array');

  -- RLS on tenant table
  v_result := catalog.schema_table('workbench', 'tenant');
  RETURN NEXT is((v_result->'rls'->>'enabled')::bool, true, 'RLS is enabled on tenant');
  RETURN NEXT ok(jsonb_array_length(v_result->'rls'->'policies') > 0, 'tenant has RLS policies');
END;
$function$;
