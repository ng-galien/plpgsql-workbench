CREATE OR REPLACE FUNCTION catalog_ut.test_schema_comments()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
BEGIN
  v_result := catalog.schema_comments('workbench');

  RETURN NEXT ok(v_result IS NOT NULL, 'returns text');
  RETURN NEXT ok(v_result LIKE 'SCHEMA workbench%', 'starts with SCHEMA header');
  RETURN NEXT ok(v_result LIKE '%## agent_message%', 'contains agent_message table section');
  RETURN NEXT ok(v_result LIKE '%## tenant%', 'contains tenant table section');
  RETURN NEXT ok(v_result LIKE '%msg_type:%', 'contains column msg_type');
END;
$function$;
