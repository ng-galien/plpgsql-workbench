CREATE OR REPLACE FUNCTION pgv_ut.test_schema_comments()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
BEGIN
  v_result := pgv.schema_comments('document');

  RETURN NEXT ok(v_result IS NOT NULL, 'returns text');
  RETURN NEXT ok(v_result LIKE 'SCHEMA document%', 'starts with SCHEMA header');
  RETURN NEXT ok(v_result LIKE '%## document%', 'contains document table section');
  RETURN NEXT ok(v_result LIKE '%## page%', 'contains page table section');
  RETURN NEXT ok(v_result LIKE '%format:%', 'contains column format');
END;
$function$;
