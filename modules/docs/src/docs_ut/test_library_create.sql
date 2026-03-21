CREATE OR REPLACE FUNCTION docs_ut.test_library_create()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id text;
  v_lib record;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);
  DELETE FROM docs.library WHERE tenant_id = 'test';

  v_id := docs.library_create('My French Tour', 'Photos oenotourisme Bourgogne');

  RETURN NEXT ok(v_id IS NOT NULL, 'library_create returns id');

  SELECT * INTO v_lib FROM docs.library WHERE id = v_id;
  RETURN NEXT is(v_lib.name, 'My French Tour', 'name stored');
  RETURN NEXT is(v_lib.description, 'Photos oenotourisme Bourgogne', 'description stored');

  -- Unique name per tenant
  BEGIN
    PERFORM docs.library_create('My French Tour');
    RETURN NEXT fail('duplicate name should raise');
  EXCEPTION WHEN unique_violation THEN
    RETURN NEXT pass('duplicate name raises unique_violation');
  END;

  DELETE FROM docs.library WHERE tenant_id = 'test';
END;
$function$;
