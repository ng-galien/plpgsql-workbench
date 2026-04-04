CREATE OR REPLACE FUNCTION catalog_ut.test_schema_inspect()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v text;
BEGIN
  -- Ensure api.expose=mcp flags are set (may be reset by docs agent redeploys)
  ALTER FUNCTION docs.charter_create(docs.charter) SET api.expose = 'mcp';
  ALTER FUNCTION docs.charter_read(text) SET api.expose = 'mcp';
  ALTER FUNCTION docs.charter_list() SET api.expose = 'mcp';
  ALTER FUNCTION docs.charter_delete(text) SET api.expose = 'mcp';
  ALTER FUNCTION docs.charter_tokens_to_css(text) SET api.expose = 'mcp';
  ALTER FUNCTION docs.charter_check(text, text) SET api.expose = 'mcp';
  ALTER FUNCTION docs.document_duplicate(text, text) SET api.expose = 'mcp';
  ALTER FUNCTION docs.document_print_css(text) SET api.expose = 'mcp';

  -- charter: full inspection
  v := catalog.schema_inspect('docs', 'charter');
  RETURN NEXT ok(v LIKE '## charter%', 'charter: header');
  RETURN NEXT ok(v LIKE '%attributes:%', 'charter: has attributes section');
  RETURN NEXT ok(v LIKE '%id%text%PK%', 'charter: id is PK');
  RETURN NEXT ok(v LIKE '%color_extra%jsonb%', 'charter: jsonb column present');
  RETURN NEXT ok(v LIKE '%voice_personality%text[]%', 'charter: array type formatted as text[]');

  -- CRUD
  RETURN NEXT ok(v LIKE '%crud:%', 'charter: has crud section');
  RETURN NEXT ok(v LIKE '%charter_create%', 'charter: create function listed');
  RETURN NEXT ok(v LIKE '%charter_read%', 'charter: read function listed');
  RETURN NEXT ok(v LIKE '%charter_list%', 'charter: list function listed');
  RETURN NEXT ok(v LIKE '%charter_delete%', 'charter: delete function listed');

  -- Methods
  RETURN NEXT ok(v LIKE '%methods:%', 'charter: has methods section');
  RETURN NEXT ok(v LIKE '%charter_tokens_to_css%', 'charter: tokens_to_css method');
  RETURN NEXT ok(v LIKE '%charter_check%', 'charter: check method');

  -- Relations
  RETURN NEXT ok(v LIKE '%relations:%', 'charter: has relations section');
  RETURN NEXT ok(v LIKE '%document -> charter_id FK%', 'charter: document FK relation');
  RETURN NEXT ok(v LIKE '%charter_revision -> charter_id FK%', 'charter: charter_revision FK relation');

  -- document: FK + methods
  v := catalog.schema_inspect('docs', 'document');
  RETURN NEXT ok(v LIKE '%charter_id%FK%', 'document: charter_id is FK');
  RETURN NEXT ok(v LIKE '%document_duplicate%', 'document: duplicate method');
  RETURN NEXT ok(v LIKE '%document_print_css%', 'document: print_css method');

  -- Missing entity
  v := catalog.schema_inspect('docs', 'nonexistent');
  RETURN NEXT ok(v LIKE '%not found%', 'missing entity: error message');


END;
$function$;
