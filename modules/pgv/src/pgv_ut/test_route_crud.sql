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
  v := pgv.route_crud('get', 'docs://charte#schema');
  RETURN NEXT is(v->'data'->>'table', 'charte', 'schema: returns table detail');

  -- get schema://entity → list
  v := pgv.route_crud('get', 'docs://charte');
  RETURN NEXT ok(v ? 'data', 'list: has data key');
  RETURN NEXT is(v->>'uri', 'docs://charte', 'list: uri preserved');

  -- get schema://entity/{id} → read (fallback to _load)
  v := pgv.route_crud('get', 'docs://charte/nonexistent_id');
  RETURN NEXT ok(v ? 'data', 'read: has data key');

  -- HATEOAS: actions filtered by api.expose=mcp
  v := pgv.route_crud('get', 'docs://charte/test');
  RETURN NEXT ok(jsonb_typeof(v->'actions') = 'array', 'hateoas: actions is array');
  RETURN NEXT ok(
    EXISTS (SELECT 1 FROM jsonb_array_elements(v->'actions') a WHERE a->>'verb' = 'delete'),
    'hateoas: delete action present (api.expose=mcp)'
  );
  RETURN NEXT ok(
    EXISTS (SELECT 1 FROM jsonb_array_elements(v->'actions') a WHERE a->>'method' = 'tokens_to_css'),
    'hateoas: custom method tokens_to_css (api.expose=mcp)'
  );

  -- Slug in HATEOAS actions
  v := pgv.route_crud('get', 'docs://charte/ocean');
  RETURN NEXT ok(
    EXISTS (SELECT 1 FROM jsonb_array_elements(v->'actions') a WHERE a->>'uri' LIKE '%/ocean/%'),
    'slug: HATEOAS URIs contain slug'
  );

  -- Error: nonexistent schema
  v := pgv.route_crud('get', 'nonexistent://test');
  RETURN NEXT is(v->>'error', 'not_found', 'error: bad schema');

  -- Error: nonexistent entity
  v := pgv.route_crud('get', 'docs://fakentity');
  RETURN NEXT is(v->>'error', 'not_found', 'error: bad entity');

  -- Error: bad verb
  v := pgv.route_crud('badverb', 'docs://charte');
  RETURN NEXT is(v->>'error', 'bad_request', 'error: bad verb');

  -- Error: POST without method
  v := pgv.route_crud('post', 'docs://charte/test');
  RETURN NEXT is(v->>'error', 'bad_request', 'error: post without method');

  -- Slug-based read
  v := pgv.route_crud('get', 'docs://charte/my-slug-name');
  RETURN NEXT ok(v ? 'data', 'slug: read passes segment to _read');
  RETURN NEXT is(v->>'uri', 'docs://charte/my-slug-name', 'slug: uri preserved with slug');
END;
$function$;
