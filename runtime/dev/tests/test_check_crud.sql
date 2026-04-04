CREATE OR REPLACE FUNCTION dev_ut.test_check_crud()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v text;
BEGIN
  v := dev.check_crud('docs');

  -- Header
  RETURN NEXT ok(v LIKE 'check_crud: docs%', 'header present');

  -- Entities with CRUD detected
  RETURN NEXT ok(v LIKE '%charter — create read list%delete%', 'charter: CRUD detected');
  RETURN NEXT ok(v LIKE '%document — create read list%delete%', 'document: CRUD detected');
  RETURN NEXT ok(v LIKE '%library — create read list%delete%', 'library: CRUD detected');

  -- Naming warning
  RETURN NEXT ok(v LIKE '%⚠ naming: page_remove%', 'naming: page_remove detected');

  -- Entities without CRUD get warning
  RETURN NEXT ok(v LIKE '%⚠ page — no CRUD%', 'page: no CRUD warning');
  RETURN NEXT ok(v LIKE '%⚠ session — no CRUD%', 'session: no CRUD warning');

  -- Summary
  RETURN NEXT ok(v LIKE '%warning(s)%', 'summary has warnings');

  -- Schema with no issues (pgv_qa has product table but no CRUD)
  v := dev.check_crud('pgv_qa');
  RETURN NEXT ok(v LIKE '%check_crud: pgv_qa%', 'pgv_qa: runs without error');
END;
$function$;
