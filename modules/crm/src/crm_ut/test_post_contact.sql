CREATE OR REPLACE FUNCTION crm_ut.test_post_contact()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client_id int;
  v_contact_id int;
  v_result text;
  v_contact crm.contact;
BEGIN
  INSERT INTO crm.client (type, name) VALUES ('company', 'Contact Test Co') RETURNING id INTO v_client_id;

  -- Add contact
  v_result := crm.post_contact_add(jsonb_build_object('client_id', v_client_id, 'name', 'Marie', 'role', 'Directrice', 'email', 'marie@test.com', 'is_primary', true));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'add returns success');

  SELECT * INTO v_contact FROM crm.contact WHERE client_id = v_client_id;
  RETURN NEXT is(v_contact.name, 'Marie'::text, 'name saved');
  RETURN NEXT is(v_contact.role, 'Directrice'::text, 'role saved');
  RETURN NEXT is(v_contact.is_primary, true, 'is_primary saved');
  v_contact_id := v_contact.id;

  -- Validation: empty name
  v_result := crm.post_contact_add(jsonb_build_object('client_id', v_client_id, 'name', ''));
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'empty name returns error');

  -- Delete contact
  v_result := crm.post_contact_delete(jsonb_build_object('id', v_contact_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'delete returns success');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM crm.contact WHERE id = v_contact_id), 'contact deleted');

  DELETE FROM crm.client WHERE id = v_client_id;
END;
$function$;
