CREATE OR REPLACE FUNCTION crm.post_contact_add(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client_id int := (p_data->>'client_id')::int;
BEGIN
  IF trim(COALESCE(p_data->>'name', '')) = '' THEN
    RETURN pgv.toast(pgv.t('crm.err_name_required'), 'error');
  END IF;

  INSERT INTO crm.contact (client_id, name, role, email, phone, is_primary)
  VALUES (
    v_client_id,
    trim(p_data->>'name'),
    COALESCE(p_data->>'role', ''),
    NULLIF(trim(p_data->>'email'), ''),
    NULLIF(trim(p_data->>'phone'), ''),
    COALESCE((p_data->>'is_primary')::boolean, false)
  );

  RETURN pgv.toast(pgv.t('crm.toast_contact_added'))
      || pgv.redirect(pgv.call_ref('get_client', jsonb_build_object('p_id', v_client_id)));
END;
$function$;
