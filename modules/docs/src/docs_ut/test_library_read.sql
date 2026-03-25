CREATE OR REPLACE FUNCTION docs_ut.test_library_read()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_j jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.library WHERE tenant_id = 'test';

  v_j := docs.library_create(jsonb_populate_record(NULL::docs.library, '{"name":"Read Test","description":"Test library"}'::jsonb));

  v_j := docs.library_read(v_j->>'id');

  RETURN NEXT ok(v_j->>'id' IS NOT NULL, 'library_read returns data');
  RETURN NEXT is(v_j->>'name', 'Read Test', 'name in result');
  RETURN NEXT is(v_j->>'description', 'Test library', 'description');

  RETURN NEXT ok(docs.library_read('nonexistent') IS NULL, 'NULL for unknown library');

  DELETE FROM docs.library WHERE tenant_id = 'test';
END;
$function$;
