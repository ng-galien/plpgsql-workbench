CREATE OR REPLACE FUNCTION catalog_ut.test_schema_discover()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_table jsonb;
  v_col jsonb;
BEGIN
  v_result := catalog.schema_discover('workbench');

  RETURN NEXT ok(jsonb_typeof(v_result) = 'array', 'returns jsonb array');
  RETURN NEXT ok(jsonb_array_length(v_result) >= 5, 'workbench has >= 5 tables');

  -- Find agent_message table
  SELECT item INTO v_table FROM jsonb_array_elements(v_result) AS item
  WHERE item->>'table' = 'agent_message';
  RETURN NEXT ok(v_table IS NOT NULL, 'agent_message table found');

  -- Columns
  RETURN NEXT ok(jsonb_array_length(v_table->'columns') > 5, 'agent_message has > 5 columns');

  -- Check a specific column
  SELECT col INTO v_col FROM jsonb_array_elements(v_table->'columns') AS col
  WHERE col->>'name' = 'msg_type';
  RETURN NEXT ok(v_col IS NOT NULL, 'msg_type column found');
  RETURN NEXT is(v_col->>'type', 'text', 'msg_type is text type');
  RETURN NEXT is((v_col->>'nullable')::bool, false, 'msg_type is NOT NULL');

  -- FK
  RETURN NEXT ok(jsonb_typeof(v_table->'foreign_keys') = 'array', 'foreign_keys is array');

  -- Empty schema
  v_result := catalog.schema_discover('nonexistent_schema_xyz');
  RETURN NEXT is(v_result, '[]'::jsonb, 'nonexistent schema returns empty array');
END;
$function$;
