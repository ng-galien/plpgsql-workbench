CREATE OR REPLACE FUNCTION crm_ut.test_post_client_save()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result text;
  v_client crm.client;
  v_id int;
BEGIN
  -- Create
  v_result := crm.post_client_save('{"name":"Test Client","type":"individual","email":"test@example.com","tags":"plomberie, Urgent, plomberie","city":"Lyon"}'::jsonb);
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'create returns success toast');
  RETURN NEXT ok(v_result LIKE '%data-redirect%', 'create returns redirect');

  SELECT id INTO v_id FROM crm.client WHERE name = 'Test Client';
  SELECT * INTO v_client FROM crm.client WHERE id = v_id;
  RETURN NEXT is(v_client.email, 'test@example.com'::text, 'email saved');
  RETURN NEXT is(v_client.city, 'Lyon'::text, 'city saved');
  RETURN NEXT ok(v_client.tags @> ARRAY['plomberie','urgent'], 'tags normalized and deduplicated');
  RETURN NEXT is(array_length(v_client.tags, 1), 2, 'duplicate tag removed');

  -- Update
  v_result := crm.post_client_save(('{"id":' || v_id || ',"name":"Test Updated","type":"company","tier":"premium"}')::jsonb);
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'update returns success toast');
  SELECT * INTO v_client FROM crm.client WHERE id = v_id;
  RETURN NEXT is(v_client.name, 'Test Updated'::text, 'name updated');
  RETURN NEXT is(v_client.tier, 'premium'::text, 'tier updated');

  -- Validation: empty name
  v_result := crm.post_client_save('{"name":""}'::jsonb);
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'empty name returns error');

  -- Cleanup
  DELETE FROM crm.client WHERE id = v_id;
END;
$function$;
