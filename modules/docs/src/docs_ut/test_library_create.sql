CREATE OR REPLACE FUNCTION docs_ut.test_library_create()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_lib docs.library;
  v_r record;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.library WHERE tenant_id = 'test';

  v_lib := docs.library_create(jsonb_populate_record(NULL::docs.library, '{"name":"My French Tour","description":"Photos oenotourisme Bourgogne"}'::jsonb));

  RETURN NEXT ok(v_lib.id IS NOT NULL, 'library_create returns id');

  SELECT * INTO v_r FROM docs.library WHERE id = v_lib.id;
  RETURN NEXT is(v_r.name, 'My French Tour', 'name stored');
  RETURN NEXT is(v_r.description, 'Photos oenotourisme Bourgogne', 'description stored');

  -- Unique name per tenant
  BEGIN
    PERFORM docs.library_create(jsonb_populate_record(NULL::docs.library, '{"name":"My French Tour"}'::jsonb));
    RETURN NEXT fail('duplicate name should raise');
  EXCEPTION WHEN unique_violation THEN
    RETURN NEXT pass('duplicate name raises unique_violation');
  END;

  DELETE FROM docs.library WHERE tenant_id = 'test';
END;
$function$;
