CREATE OR REPLACE FUNCTION crm_ut.test_post_client_delete()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_result text;
BEGIN
  INSERT INTO crm.client (type, name) VALUES ('individual', 'To Delete') RETURNING id INTO v_id;
  INSERT INTO crm.interaction (client_id, type, subject) VALUES (v_id, 'note', 'Test note');
  INSERT INTO crm.contact (client_id, name) VALUES (v_id, 'Contact Test');

  v_result := crm.post_client_delete(jsonb_build_object('id', v_id));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'delete returns success');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'delete redirects');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM crm.client WHERE id = v_id), 'client deleted');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM crm.interaction WHERE client_id = v_id), 'interactions cascaded');
  RETURN NEXT ok(NOT EXISTS(SELECT 1 FROM crm.contact WHERE client_id = v_id), 'contacts cascaded');
END;
$function$;
