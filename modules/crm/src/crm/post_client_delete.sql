CREATE OR REPLACE FUNCTION crm.post_client_delete(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN
  DELETE FROM crm.client WHERE id = (p_data->>'id')::int;
  RETURN pgv.toast(pgv.t('crm.toast_client_deleted'))
      || pgv.redirect(pgv.call_ref('get_index'));
END;
$function$;
