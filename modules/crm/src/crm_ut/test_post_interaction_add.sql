CREATE OR REPLACE FUNCTION crm_ut.test_post_interaction_add()
 RETURNS SETOF text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int;
  v_result text;
  v_interaction crm.interaction;
BEGIN
  INSERT INTO crm.client (type, name) VALUES ('individual', 'Interaction Test') RETURNING id INTO v_id;

  v_result := crm.post_interaction_add(jsonb_build_object('client_id', v_id, 'type', 'call', 'subject', 'Appel test', 'body', 'Détails'));
  RETURN NEXT ok(v_result LIKE '%data-toast="success"%', 'add returns success');

  SELECT * INTO v_interaction FROM crm.interaction WHERE client_id = v_id;
  RETURN NEXT is(v_interaction.type, 'call'::text, 'type saved');
  RETURN NEXT is(v_interaction.subject, 'Appel test'::text, 'subject saved');
  RETURN NEXT is(v_interaction.body, 'Détails'::text, 'body saved');

  -- Validation: empty subject
  v_result := crm.post_interaction_add(jsonb_build_object('client_id', v_id, 'subject', ''));
  RETURN NEXT ok(v_result LIKE '%data-toast="error"%', 'empty subject returns error');

  DELETE FROM crm.client WHERE id = v_id;
END;
$function$;
