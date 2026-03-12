CREATE OR REPLACE FUNCTION crm_ut.test_post_contact_delete()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client_id int;
  v_contact_id int;
  v_result text;
BEGIN
  PERFORM set_config('app.tenant_id', 'test', true);

  INSERT INTO crm.client (type, name) VALUES ('company', 'Contact Del Test Co') RETURNING id INTO v_client_id;
  INSERT INTO crm.contact (client_id, name, role) VALUES (v_client_id, 'To Delete', 'Test') RETURNING id INTO v_contact_id;

  -- Nominal: delete contact
  v_result := crm.post_contact_delete(jsonb_build_object('id', v_contact_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'delete returns success');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'delete returns redirect');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM crm.contact WHERE id = v_contact_id), 'contact deleted from DB');

  -- Cleanup
  DELETE FROM crm.client WHERE id = v_client_id;
END;
$function$;
