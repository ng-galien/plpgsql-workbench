CREATE OR REPLACE FUNCTION sdui_ut.test_api()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v jsonb;
  v_client_id int;
BEGIN
  PERFORM set_config('app.tenant_id', 'dev', true);

  v := sdui.api('get', '://');
  RETURN NEXT ok(jsonb_typeof(v->'data') = 'array', 'catalog: returns array');
  RETURN NEXT is(v->>'uri', '://', 'catalog: uri preserved');

  v := sdui.api('get', 'docs://');
  RETURN NEXT ok(jsonb_typeof(v->'data') = 'array', 'discover: returns array');

  v := sdui.api('get', 'docs://charter#schema');
  RETURN NEXT is(v->'data'->>'table', 'charter', 'schema: returns table detail');

  v := sdui.api('get', 'docs://charter');
  RETURN NEXT ok(v ? 'data', 'list: has data key');
  RETURN NEXT is(v->>'uri', 'docs://charter', 'list: uri preserved');
  IF jsonb_typeof(v->'data') = 'array' AND jsonb_array_length(v->'data') > 0 THEN
    RETURN NEXT ok(NOT ((v->'data'->0) ? 'ui'), 'list: rows do not embed ui');
  END IF;

  v := sdui.api('get', 'docs://charter/nonexistent_id');
  RETURN NEXT ok(v ? 'data', 'read: has data key');

  v := sdui.api('get', 'docs://charter/test');
  RETURN NEXT ok(jsonb_typeof(v->'actions') = 'array', 'hateoas: actions is array');
  RETURN NEXT ok(v ? 'actions', 'hateoas: actions key always present');

  v := sdui.api('get', 'nonexistent://test');
  RETURN NEXT is((v->>'status')::int, 404, 'error: bad schema returns 404');
  RETURN NEXT is(v->>'type', 'about:blank', 'error: bad schema has type');
  RETURN NEXT ok(v ? 'detail', 'error: bad schema has detail');

  v := sdui.api('get', 'docs://fakentity');
  RETURN NEXT is((v->>'status')::int, 404, 'error: bad entity returns 404');

  v := sdui.api('badverb', 'docs://charter');
  RETURN NEXT is((v->>'status')::int, 400, 'error: bad verb returns 400');

  v := sdui.api('post', 'docs://charter/test');
  RETURN NEXT is((v->>'status')::int, 400, 'error: post without method returns 400');

  v := sdui.api('get', 'docs://charter/my-slug-name');
  RETURN NEXT ok(v ? 'data', 'slug: read passes segment to _read');
  RETURN NEXT is(v->>'uri', 'docs://charter/my-slug-name', 'slug: uri preserved with slug');

  PERFORM set_config('app.permissions', 'crm.client.create,crm.client.read,crm.client.modify', true);
  INSERT INTO crm.client (tenant_id, type, name, email, phone, city, tier, active)
  VALUES ('dev', 'company', 'Jean Dupont', 'jean@example.com', '06 12 34 56 78', 'Paris', 'standard', true)
  RETURNING id INTO v_client_id;

  v := sdui.api('set', 'crm://client', '{"type":"company","name":"New Client","email":"new@example.com"}'::jsonb);
  RETURN NEXT is(v->'data'->>'name', 'New Client', 'set: creates row through jsonb contract');
  RETURN NEXT ok(v->'data' ? 'ui', 'set: embeds ui on single-row result');

  v := sdui.api('patch', format('crm://client/%s', v_client_id), '{"phone": "09 99 99 99 99"}'::jsonb);
  RETURN NEXT is(v->'data'->>'phone', '09 99 99 99 99', 'patch: field updated');
  RETURN NEXT is(v->'data'->>'name', 'Jean Dupont', 'patch: unpatched field preserved');
  RETURN NEXT ok((v->'data'->>'type') IS NOT NULL, 'patch: NOT NULL fields preserved');
  RETURN NEXT ok(v->'data' ? 'ui', 'patch: embeds ui on single-row result');

  v := sdui.api('patch', 'crm://client/999999', '{"phone": "00"}'::jsonb);
  RETURN NEXT is((v->>'status')::int, 404, 'patch: nonexistent row returns 404');
  RETURN NEXT is(v->>'instance', 'crm://client/999999', 'patch: instance is the URI');
END; $function$;
