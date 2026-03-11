CREATE OR REPLACE FUNCTION crm.post_contact_delete(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client_id int;
BEGIN
  SELECT client_id INTO v_client_id FROM crm.contact WHERE id = (p_data->>'id')::int;
  DELETE FROM crm.contact WHERE id = (p_data->>'id')::int;

  RETURN '<template data-toast="success">Contact supprimé.</template>'
      || '<template data-redirect="' || pgv.call_ref('get_client', jsonb_build_object('p_id', v_client_id)) || '"></template>';
END;
$function$;
