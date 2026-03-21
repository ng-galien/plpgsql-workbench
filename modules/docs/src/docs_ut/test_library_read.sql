CREATE OR REPLACE FUNCTION docs_ut.test_library_read()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_lib docs.library;
  v_r docs.library;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.library WHERE tenant_id = 'test';

  v_lib := docs.library_create(jsonb_populate_record(NULL::docs.library, '{"name":"Read Test","description":"Test library"}'::jsonb));

  v_r := docs.library_read(v_lib.id);

  RETURN NEXT ok(v_r.id IS NOT NULL, 'library_read returns data');
  RETURN NEXT is(v_r.name, 'Read Test', 'name in result');
  RETURN NEXT is(v_r.description, 'Test library', 'description');

  -- Not found
  RETURN NEXT ok((docs.library_read('nonexistent')).id IS NULL, 'NULL for unknown library');

  DELETE FROM docs.library WHERE tenant_id = 'test';
END;
$function$;
