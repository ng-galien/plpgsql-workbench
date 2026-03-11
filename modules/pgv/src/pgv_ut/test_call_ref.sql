CREATE OR REPLACE FUNCTION pgv_ut.test_call_ref()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Without route prefix (app mode): no validation, simple path
  PERFORM set_config('pgv.route_prefix', '', true);

  RETURN NEXT is(pgv.call_ref('get_index'), '/',
    'get_index without prefix → /');

  RETURN NEXT is(pgv.call_ref('get_drawings'), '/drawings',
    'get_drawings without prefix → /drawings');

  RETURN NEXT is(pgv.call_ref('get_drawing', '{"id": "42"}'::jsonb), '/drawing?id=42',
    'get_drawing with param → /drawing?id=42');

  RETURN NEXT is(pgv.call_ref('post_save', '{"id": "1", "name": "test"}'::jsonb), '/save?id=1&name=test',
    'post_save with multiple params → query string');

  -- With route prefix (dev mode): validates against pg_proc
  PERFORM set_config('pgv.route_prefix', '/pgv_qa', true);

  RETURN NEXT is(pgv.call_ref('get_index'), '/pgv_qa/',
    'get_index with prefix → /pgv_qa/');

  RETURN NEXT is(pgv.call_ref('get_atoms'), '/pgv_qa/atoms',
    'get_atoms (exists in pgv_qa) → /pgv_qa/atoms');

  -- Dead link detection
  RETURN NEXT throws_ok(
    $$SELECT pgv.call_ref('get_does_not_exist')$$,
    'P0001',
    'pgv.call_ref: function pgv_qa.get_does_not_exist not found',
    'dead link raises exception'
  );
END;
$function$;
