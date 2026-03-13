CREATE OR REPLACE FUNCTION planning._intervenant_form_inputs(p_id integer DEFAULT NULL::integer, p_nom text DEFAULT NULL::text, p_role text DEFAULT NULL::text, p_telephone text DEFAULT NULL::text, p_couleur text DEFAULT NULL::text, p_actif boolean DEFAULT true)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN format('<input type="hidden" name="id" value="%s">', COALESCE(p_id::text, ''))
    || pgv.input('nom', 'text', pgv.t('planning.field_nom') || ' *', p_nom, true)
    || pgv.input('role', 'text', pgv.t('planning.field_role') || ' (' || pgv.t('planning.field_role_hint') || ')', p_role)
    || pgv.input('telephone', 'tel', pgv.t('planning.field_telephone'), p_telephone)
    || pgv.input('couleur', 'color', pgv.t('planning.field_couleur'), COALESCE(p_couleur, '#3b82f6'))
    || pgv.toggle('actif', pgv.t('planning.field_actif'), COALESCE(p_actif, true));
END;
$function$;
