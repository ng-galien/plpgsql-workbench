CREATE OR REPLACE FUNCTION catalog_ut.test_schema_catalog()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result jsonb;
  v_item jsonb;
BEGIN
  v_result := catalog.schema_catalog();

  RETURN NEXT ok(jsonb_typeof(v_result) = 'array', 'returns jsonb array');
  RETURN NEXT ok(jsonb_array_length(v_result) > 0, 'at least one schema');

  -- workbench should be present
  SELECT item INTO v_item FROM jsonb_array_elements(v_result) AS item
  WHERE item->>'schema' = 'workbench';
  RETURN NEXT ok(v_item IS NOT NULL, 'workbench schema present');
  RETURN NEXT ok((v_item->>'tables')::int > 0, 'workbench has tables');
  RETURN NEXT ok((v_item->>'functions')::int > 0, 'workbench has functions');

  -- pgv should NOT be present (framework, not app)
  -- Actually pgv IS an app schema — check _ut/_qa excluded
  SELECT item INTO v_item FROM jsonb_array_elements(v_result) AS item
  WHERE item->>'schema' = 'pgv_ut';
  RETURN NEXT ok(v_item IS NULL, 'pgv_ut excluded');

  SELECT item INTO v_item FROM jsonb_array_elements(v_result) AS item
  WHERE item->>'schema' = 'pgv_qa';
  RETURN NEXT ok(v_item IS NULL, 'pgv_qa excluded');

  SELECT item INTO v_item FROM jsonb_array_elements(v_result) AS item
  WHERE item->>'schema' = 'information_schema';
  RETURN NEXT ok(v_item IS NULL, 'information_schema excluded');
END;
$function$;
