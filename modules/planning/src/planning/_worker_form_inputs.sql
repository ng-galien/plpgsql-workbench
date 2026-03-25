CREATE OR REPLACE FUNCTION planning._worker_form_inputs(p_id integer DEFAULT NULL::integer, p_name text DEFAULT NULL::text, p_role text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_color text DEFAULT NULL::text, p_active boolean DEFAULT true)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN format('<input type="hidden" name="id" value="%s">', COALESCE(p_id::text, ''))
    || pgv.input('name', 'text', pgv.t('planning.field_name') || ' *', p_name, true)
    || pgv.input('role', 'text', pgv.t('planning.field_role') || ' (' || pgv.t('planning.field_role_hint') || ')', p_role)
    || pgv.input('phone', 'tel', pgv.t('planning.field_phone'), p_phone)
    || pgv.input('color', 'color', pgv.t('planning.field_color'), COALESCE(p_color, '#3b82f6'))
    || pgv.toggle('active', pgv.t('planning.field_active'), COALESCE(p_active, true));
END;
$function$;
