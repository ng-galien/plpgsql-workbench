CREATE OR REPLACE FUNCTION crm.client_form_fields(p_client crm.client DEFAULT NULL::crm.client)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_tags_str text;
BEGIN
  v_tags_str := CASE WHEN p_client.id IS NOT NULL THEN array_to_string(p_client.tags, ', ') ELSE '' END;

  RETURN CASE WHEN p_client.id IS NOT NULL THEN '<input type="hidden" name="id" value="' || p_client.id || '">' ELSE '' END
    || pgv.sel('type', pgv.t('crm.field_type'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('crm.type_individual'), 'value', 'individual'),
         jsonb_build_object('label', pgv.t('crm.type_company'), 'value', 'company')
       ), CASE WHEN p_client.id IS NOT NULL THEN p_client.type ELSE 'individual' END)
    || pgv.input('name', 'text', pgv.t('crm.field_name'), p_client.name, true)
    || pgv.input('email', 'email', pgv.t('crm.field_email'), p_client.email)
    || pgv.input('phone', 'tel', pgv.t('crm.field_phone'), p_client.phone)
    || pgv.input('address', 'text', pgv.t('crm.field_address'), p_client.address)
    || '<div class="grid">'
    || pgv.input('city', 'text', pgv.t('crm.field_city'), p_client.city)
    || pgv.input('postal_code', 'text', pgv.t('crm.field_postal_code'), p_client.postal_code)
    || '</div>'
    || pgv.sel('tier', pgv.t('crm.field_tier'), '["standard","premium","vip"]'::jsonb,
        CASE WHEN p_client.id IS NOT NULL THEN p_client.tier ELSE 'standard' END)
    || pgv.input('tags', 'text', pgv.t('crm.field_tags'), v_tags_str)
    || pgv.textarea('notes', pgv.t('crm.field_notes'), CASE WHEN p_client.id IS NOT NULL AND p_client.notes <> '' THEN p_client.notes ELSE NULL END)
    || CASE WHEN p_client.id IS NOT NULL THEN
        pgv.checkbox('active', pgv.t('crm.field_active'), p_client.active)
       ELSE '' END;
END;
$function$;
