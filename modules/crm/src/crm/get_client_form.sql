CREATE OR REPLACE FUNCTION crm.get_client_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_client crm.client;
  v_title text;
  v_body text;
  v_tags_str text;
  v_fields text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_client FROM crm.client WHERE id = p_id;
    IF NOT FOUND THEN
      RETURN pgv.alert(pgv.t('crm.err_not_found'), 'danger');
    END IF;
    v_title := pgv.t('crm.btn_edit') || ' ' || pgv.esc(v_client.name);
    v_tags_str := array_to_string(v_client.tags, ', ');
  ELSE
    v_title := pgv.t('crm.title_new_client');
    v_tags_str := '';
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    pgv.t('crm.nav_clients'), pgv.call_ref('get_index'),
    v_title
  ]);

  v_fields := CASE WHEN p_id IS NOT NULL THEN '<input type="hidden" name="id" value="' || p_id || '">' ELSE '' END
    || pgv.sel('type', pgv.t('crm.field_type'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('crm.type_individual'), 'value', 'individual'),
         jsonb_build_object('label', pgv.t('crm.type_company'), 'value', 'company')
       ), CASE WHEN p_id IS NOT NULL THEN v_client.type ELSE 'individual' END)
    || pgv.input('name', 'text', pgv.t('crm.field_name'), v_client.name, true)
    || pgv.input('email', 'email', pgv.t('crm.field_email'), v_client.email)
    || pgv.input('phone', 'tel', pgv.t('crm.field_phone'), v_client.phone)
    || pgv.input('address', 'text', pgv.t('crm.field_address'), v_client.address)
    || '<div class="grid">'
    || pgv.input('city', 'text', pgv.t('crm.field_city'), v_client.city)
    || pgv.input('postal_code', 'text', pgv.t('crm.field_postal_code'), v_client.postal_code)
    || '</div>'
    || pgv.sel('tier', pgv.t('crm.field_tier'), '["standard","premium","vip"]'::jsonb,
        CASE WHEN p_id IS NOT NULL THEN v_client.tier ELSE 'standard' END)
    || pgv.input('tags', 'text', pgv.t('crm.field_tags'), v_tags_str)
    || pgv.textarea('notes', pgv.t('crm.field_notes'), CASE WHEN p_id IS NOT NULL AND v_client.notes <> '' THEN v_client.notes ELSE NULL END)
    || CASE WHEN p_id IS NOT NULL THEN
        pgv.checkbox('active', pgv.t('crm.field_active'), v_client.active)
       ELSE '' END;

  v_body := v_body || pgv.form('post_client_save', v_fields,
    CASE WHEN p_id IS NOT NULL THEN pgv.t('crm.btn_save') ELSE pgv.t('crm.btn_create_client') END);

  RETURN v_body;
END;
$function$;
