CREATE OR REPLACE FUNCTION pgv_ut.test_route_crud()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v jsonb;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  -- get :// → catalog
  v := pgv.route_crud('get', '://');
  RETURN NEXT ok(jsonb_typeof(v->'data') = 'array', 'catalog: returns array');
  RETURN NEXT is(v->>'uri', '://', 'catalog: uri preserved');

  -- get schema:// → discover
  v := pgv.route_crud('get', 'docs://');
  RETURN NEXT ok(jsonb_typeof(v->'data') = 'array', 'discover: returns array');

  -- get schema://entity#schema → schema_table
  v := pgv.route_crud('get', 'docs://charter#schema');
  RETURN NEXT is(v->'data'->>'table', 'charter', 'schema: returns table detail');

  -- get schema://entity → list
  v := pgv.route_crud('get', 'docs://charter');
  RETURN NEXT ok(v ? 'data', 'list: has data key');
  RETURN NEXT is(v->>'uri', 'docs://charter', 'list: uri preserved');

  -- get schema://entity/{id} → read (fallback to _load)
  v := pgv.route_crud('get', 'docs://charter/nonexistent_id');
  RETURN NEXT ok(v ? 'data', 'read: has data key');

  -- HATEOAS: actions extracted from _read() response (module is responsible)
  v := pgv.route_crud('get', 'docs://charter/test');
  RETURN NEXT ok(jsonb_typeof(v->'actions') = 'array', 'hateoas: actions is array');
  RETURN NEXT ok(v ? 'actions', 'hateoas: actions key always present');

  -- Error: nonexistent schema
  v := pgv.route_crud('get', 'nonexistent://test');
  RETURN NEXT is(v->>'error', 'not_found', 'error: bad schema');

  -- Error: nonexistent entity
  v := pgv.route_crud('get', 'docs://fakentity');
  RETURN NEXT is(v->>'error', 'not_found', 'error: bad entity');

  -- Error: bad verb
  v := pgv.route_crud('badverb', 'docs://charter');
  RETURN NEXT is(v->>'error', 'bad_request', 'error: bad verb');

  -- Error: POST without method
  v := pgv.route_crud('post', 'docs://charter/test');
  RETURN NEXT is(v->>'error', 'bad_request', 'error: post without method');

  -- Slug-based read
  v := pgv.route_crud('get', 'docs://charter/my-slug-name');
  RETURN NEXT ok(v ? 'data', 'slug: read passes segment to _read');
  RETURN NEXT is(v->>'uri', 'docs://charter/my-slug-name', 'slug: uri preserved with slug');

  -- Patch: merge onto existing row (only patched fields change)
  v := pgv.route_crud('patch', 'crm://client/1', '{"phone": "09 99 99 99 99"}'::jsonb);
  RETURN NEXT is(v->'data'->>'phone', '09 99 99 99 99', 'patch: field updated');
  RETURN NEXT is(v->'data'->>'name', 'Jean Dupont', 'patch: unpatched field preserved');
  RETURN NEXT ok((v->'data'->>'type') IS NOT NULL, 'patch: NOT NULL fields preserved');

  -- Patch: not found
  v := pgv.route_crud('patch', 'crm://client/999999', '{"phone": "00"}'::jsonb);
  RETURN NEXT is(v->>'error', 'not_found', 'patch: nonexistent row returns not_found');

  -- Restore test data
  UPDATE crm.client SET phone = '06 12 34 56 78' WHERE id = 1;
END;
$function$;
