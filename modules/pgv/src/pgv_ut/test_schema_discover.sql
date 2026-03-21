CREATE OR REPLACE FUNCTION pgv_ut.test_schema_discover()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_table jsonb;
  v_col jsonb;
BEGIN
  v_result := pgv.schema_discover('document');

  RETURN NEXT ok(jsonb_typeof(v_result) = 'array', 'returns jsonb array');
  RETURN NEXT ok(jsonb_array_length(v_result) >= 5, 'document has >= 5 tables');

  -- Find document table
  SELECT item INTO v_table FROM jsonb_array_elements(v_result) AS item
  WHERE item->>'table' = 'document';
  RETURN NEXT ok(v_table IS NOT NULL, 'document table found');

  -- Columns
  RETURN NEXT ok(jsonb_array_length(v_table->'columns') > 10, 'document has > 10 columns');

  -- Check a specific column
  SELECT col INTO v_col FROM jsonb_array_elements(v_table->'columns') AS col
  WHERE col->>'name' = 'format';
  RETURN NEXT ok(v_col IS NOT NULL, 'format column found');
  RETURN NEXT is(v_col->>'type', 'text', 'format is text type');
  RETURN NEXT is((v_col->>'nullable')::bool, false, 'format is NOT NULL');

  -- FK
  RETURN NEXT ok(jsonb_typeof(v_table->'foreign_keys') = 'array', 'foreign_keys is array');

  -- Empty schema
  v_result := pgv.schema_discover('nonexistent_schema_xyz');
  RETURN NEXT is(v_result, '[]'::jsonb, 'nonexistent schema returns empty array');
END;
$function$;
