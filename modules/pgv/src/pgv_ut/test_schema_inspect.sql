CREATE OR REPLACE FUNCTION pgv_ut.test_schema_inspect()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v text;
BEGIN
  -- Ensure api.expose=mcp flags are set (may be reset by docs agent redeploys)
  ALTER FUNCTION docs.charte_create(docs.charte) SET api.expose = 'mcp';
  ALTER FUNCTION docs.charte_read(text) SET api.expose = 'mcp';
  ALTER FUNCTION docs.charte_list() SET api.expose = 'mcp';
  ALTER FUNCTION docs.charte_delete(text) SET api.expose = 'mcp';
  ALTER FUNCTION docs.charte_tokens_to_css(text) SET api.expose = 'mcp';
  ALTER FUNCTION docs.charte_check(text, text) SET api.expose = 'mcp';
  ALTER FUNCTION docs.document_duplicate(text, text) SET api.expose = 'mcp';
  ALTER FUNCTION docs.document_print_css(text) SET api.expose = 'mcp';

  -- charte: full inspection
  v := pgv.schema_inspect('docs', 'charte');
  RETURN NEXT ok(v LIKE '## charte%', 'charte: header');
  RETURN NEXT ok(v LIKE '%attributes:%', 'charte: has attributes section');
  RETURN NEXT ok(v LIKE '%id%text%PK%', 'charte: id is PK');
  RETURN NEXT ok(v LIKE '%color_extra%jsonb%', 'charte: jsonb column present');
  RETURN NEXT ok(v LIKE '%voice_personality%text[]%', 'charte: array type formatted as text[]');

  -- CRUD
  RETURN NEXT ok(v LIKE '%crud:%', 'charte: has crud section');
  RETURN NEXT ok(v LIKE '%charte_create%', 'charte: create function listed');
  RETURN NEXT ok(v LIKE '%charte_read%', 'charte: read function listed');
  RETURN NEXT ok(v LIKE '%charte_list%', 'charte: list function listed');
  RETURN NEXT ok(v LIKE '%charte_delete%', 'charte: delete function listed');

  -- Methods
  RETURN NEXT ok(v LIKE '%methods:%', 'charte: has methods section');
  RETURN NEXT ok(v LIKE '%charte_tokens_to_css%', 'charte: tokens_to_css method');
  RETURN NEXT ok(v LIKE '%charte_check%', 'charte: check method');

  -- Relations
  RETURN NEXT ok(v LIKE '%relations:%', 'charte: has relations section');
  RETURN NEXT ok(v LIKE '%document -> charte_id FK%', 'charte: document FK relation');
  RETURN NEXT ok(v LIKE '%charte_revision -> charte_id FK%', 'charte: charte_revision FK relation');

  -- document: FK + methods
  v := pgv.schema_inspect('docs', 'document');
  RETURN NEXT ok(v LIKE '%charte_id%FK%', 'document: charte_id is FK');
  RETURN NEXT ok(v LIKE '%document_duplicate%', 'document: duplicate method');
  RETURN NEXT ok(v LIKE '%document_print_css%', 'document: print_css method');

  -- Missing entity
  v := pgv.schema_inspect('docs', 'nonexistent');
  RETURN NEXT ok(v LIKE '%not found%', 'missing entity: error message');


END;
$function$;
