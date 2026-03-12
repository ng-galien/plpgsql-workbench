CREATE OR REPLACE FUNCTION crm_ut.test_post_import_csv()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_count int;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  -- Empty CSV
  v_result := crm.post_import_csv('{"csv":""}'::jsonb);
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'empty csv returns error');

  -- Nominal with header + semicolons
  v_result := crm.post_import_csv(('{"csv":"nom;email;telephone;adresse;ville;code_postal;type\nAlice Import;alice@test.com;0600000001;1 rue A;Paris;75001;individual\nBob Import;bob@test.com;0600000002;2 rue B;Lyon;69001;company"}')::jsonb);
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'import returns success');
  RETURN NEXT ok(v_result LIKE '%2 client(s) importé(s)%', 'imported 2 clients');

  SELECT count(*)::int INTO v_count FROM crm.client WHERE name IN ('Alice Import', 'Bob Import');
  RETURN NEXT is(v_count, 2, '2 clients in DB');

  -- Verify fields
  RETURN NEXT ok(EXISTS(SELECT 1 FROM crm.client WHERE name = 'Alice Import' AND email = 'alice@test.com' AND city = 'Paris' AND type = 'individual'), 'Alice fields correct');
  RETURN NEXT ok(EXISTS(SELECT 1 FROM crm.client WHERE name = 'Bob Import' AND type = 'company'), 'Bob type correct');

  -- Line with empty name is skipped
  v_result := crm.post_import_csv('{"csv":";skip@test.com;000\nCharlie Import;charlie@test.com;000"}'::jsonb);
  RETURN NEXT ok(v_result LIKE '%1 client(s) importé(s)%', '1 imported, empty name skipped');
  RETURN NEXT ok(v_result LIKE '%1 ignoré(s)%', '1 skipped reported');

  -- Comma separator
  v_result := crm.post_import_csv('{"csv":"Delta Import,delta@test.com,000,addr,Nice,06000,individual"}'::jsonb);
  RETURN NEXT ok(v_result LIKE '%1 client(s) importé(s)%', 'comma separator works');

  -- Cleanup
  DELETE FROM crm.client WHERE name IN ('Alice Import', 'Bob Import', 'Charlie Import', 'Delta Import');
END;
$function$;
