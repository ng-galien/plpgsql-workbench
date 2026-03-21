CREATE OR REPLACE FUNCTION pgv_ut.test_check_crud()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v text;
BEGIN
  v := pgv.check_crud('docs');

  -- Header
  RETURN NEXT ok(v LIKE 'check_crud: docs%', 'header present');

  -- Entities with full CRUD get checkmark
  RETURN NEXT ok(v LIKE '%✓ charte — create read list%delete%', 'charte: CRUD ok');
  RETURN NEXT ok(v LIKE '%✓ document — create read list%delete%', 'document: CRUD ok');
  RETURN NEXT ok(v LIKE '%✓ library — create read list delete%', 'library: full CRUD ok');

  -- Naming warning
  RETURN NEXT ok(v LIKE '%⚠ naming: page_remove%', 'naming: page_remove detected');

  -- Entities without CRUD get warning
  RETURN NEXT ok(v LIKE '%⚠ page — no CRUD%', 'page: no CRUD warning');
  RETURN NEXT ok(v LIKE '%⚠ session — no CRUD%', 'session: no CRUD warning');

  -- Summary
  RETURN NEXT ok(v LIKE '%warning(s)%', 'summary has warnings');

  -- Schema with no issues (pgv_qa has product table but no CRUD)
  v := pgv.check_crud('pgv_qa');
  RETURN NEXT ok(v LIKE '%check_crud: pgv_qa%', 'pgv_qa: runs without error');
END;
$function$;
