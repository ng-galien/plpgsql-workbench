CREATE OR REPLACE FUNCTION crm_ut.test_post_contact_add()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client_id int;
  v_result text;
  v_contact crm.contact;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  INSERT INTO crm.client (type, name) VALUES ('company', 'Contact Add Test Co') RETURNING id INTO v_client_id;

  -- Validation: empty name
  v_result := crm.post_contact_add(jsonb_build_object('client_id', v_client_id, 'name', ''));
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'empty name returns error');

  -- Nominal: add contact with all fields
  v_result := crm.post_contact_add(jsonb_build_object('client_id', v_client_id, 'name', 'Marie', 'role', 'Directrice', 'email', 'marie@test.com', 'phone', '0601020304', 'is_primary', true));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'add returns success');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'add returns redirect');

  SELECT * INTO v_contact FROM crm.contact WHERE client_id = v_client_id;
  RETURN NEXT is(v_contact.name, 'Marie'::text, 'name saved');
  RETURN NEXT is(v_contact.role, 'Directrice'::text, 'role saved');
  RETURN NEXT is(v_contact.email, 'marie@test.com'::text, 'email saved');
  RETURN NEXT is(v_contact.phone, '0601020304'::text, 'phone saved');
  RETURN NEXT is(v_contact.is_primary, true, 'is_primary saved');

  -- Cleanup
  DELETE FROM crm.client WHERE id = v_client_id;
END;
$function$;
