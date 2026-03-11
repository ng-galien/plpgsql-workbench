CREATE OR REPLACE FUNCTION crm.post_client_delete(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM crm.client WHERE id = (p_data->>'id')::int;
  RETURN '<template data-toast="success">Client supprimé.</template>'
      || '<template data-redirect="' || pgv.call_ref('get_index') || '"></template>';
END;
$function$;
