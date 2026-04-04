CREATE OR REPLACE FUNCTION crm_ut.test_client_options()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_row record;
  v_count int;
BEGIN
  -- Setup: insert a test client
  INSERT INTO crm.client (name, type, email, city, active)
  VALUES ('UT_Options_Test', 'individual', 'ut@test.com', 'Grenoble', true)
  RETURNING id INTO v_id;

  -- Test 1: found by name
  SELECT count(*) INTO v_count FROM crm.client_options('UT_Options');
  RETURN NEXT ok(v_count = 1, 'search by name finds client');

  -- Test 2: found by city
  SELECT count(*) INTO v_count FROM crm.client_options('Grenoble');
  RETURN NEXT ok(v_count >= 1, 'search by city finds client');

  -- Test 3: found by email
  SELECT count(*) INTO v_count FROM crm.client_options('ut@test');
  RETURN NEXT ok(v_count = 1, 'search by email finds client');

  -- Test 4: detail format contains city and email
  SELECT * INTO v_row FROM crm.client_options('UT_Options') LIMIT 1;
  RETURN NEXT ok(v_row.value = v_id::text, 'value is client id');
  RETURN NEXT ok(v_row.label = 'UT_Options_Test', 'label is client name');
  RETURN NEXT ok(v_row.detail LIKE '%Grenoble%', 'detail contains city');
  RETURN NEXT ok(v_row.detail LIKE '%ut@test.com%', 'detail contains email');

  -- Test 5: inactive client not returned
  UPDATE crm.client SET active = false WHERE id = v_id;
  SELECT count(*) INTO v_count FROM crm.client_options('UT_Options');
  RETURN NEXT ok(v_count = 0, 'inactive client excluded');

  -- Test 6: NULL search returns results
  SELECT count(*) INTO v_count FROM crm.client_options(NULL);
  RETURN NEXT ok(v_count > 0, 'NULL search returns all active');

  -- Cleanup
  DELETE FROM crm.client WHERE id = v_id;
END;
$function$;
