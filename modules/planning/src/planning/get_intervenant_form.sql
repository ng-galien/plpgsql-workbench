CREATE OR REPLACE FUNCTION planning.get_intervenant_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v planning.intervenant;
  v_body text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v FROM planning.intervenant WHERE id = p_id;
    IF NOT FOUND THEN
      RETURN pgv.error('404', pgv.t('planning.err_intervenant_not_found'));
    END IF;
  END IF;

  v_body := format('<form data-rpc="post_intervenant_save"><input type="hidden" name="id" value="%s">', COALESCE(p_id::text, ''))
    || pgv.input('nom', 'text', pgv.t('planning.field_nom') || ' *', v.nom, true)
    || pgv.input('role', 'text', pgv.t('planning.field_role') || ' (' || pgv.t('planning.field_role_hint') || ')', v.role)
    || pgv.input('telephone', 'tel', pgv.t('planning.field_telephone'), v.telephone)
    || pgv.input('couleur', 'color', pgv.t('planning.field_couleur'), COALESCE(v.couleur, '#3b82f6'))
    || pgv.toggle('actif', pgv.t('planning.field_actif'), COALESCE(v.actif, true))
    || '<button type="submit">' || pgv.t('planning.btn_enregistrer') || '</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
