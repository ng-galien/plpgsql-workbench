CREATE OR REPLACE FUNCTION crm.post_interaction_add(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client_id int := (p_data->>'client_id')::int;
BEGIN
  IF trim(COALESCE(p_data->>'subject', '')) = '' THEN
    RETURN '<template data-toast="error">Le sujet est obligatoire.</template>';
  END IF;

  INSERT INTO crm.interaction (client_id, type, subject, body)
  VALUES (
    v_client_id,
    COALESCE(p_data->>'type', 'note'),
    trim(p_data->>'subject'),
    COALESCE(p_data->>'body', '')
  );

  RETURN '<template data-toast="success">Interaction ajoutée.</template>'
      || '<template data-redirect="' || pgv.call_ref('get_client', jsonb_build_object('p_id', v_client_id)) || '"></template>';
END;
$function$;
