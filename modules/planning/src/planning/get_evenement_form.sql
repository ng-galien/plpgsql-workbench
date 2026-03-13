CREATE OR REPLACE FUNCTION planning.get_evenement_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v planning.evenement;
  v_body text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v FROM planning.evenement WHERE id = p_id;
    IF NOT FOUND THEN
      RETURN pgv.error('404', pgv.t('planning.err_evenement_not_found'));
    END IF;
  END IF;

  v_body := format('<form data-rpc="post_evenement_save"><input type="hidden" name="id" value="%s">', COALESCE(p_id::text, ''))
    || pgv.input('titre', 'text', pgv.t('planning.field_titre') || ' *', v.titre, true)
    || pgv.sel('type', pgv.t('planning.field_type'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('planning.type_chantier'), 'value', 'chantier'),
         jsonb_build_object('label', pgv.t('planning.type_livraison'), 'value', 'livraison'),
         jsonb_build_object('label', pgv.t('planning.type_reunion'), 'value', 'reunion'),
         jsonb_build_object('label', pgv.t('planning.type_conge'), 'value', 'conge'),
         jsonb_build_object('label', pgv.t('planning.type_autre'), 'value', 'autre')
       ), COALESCE(v.type, 'chantier'))
    || '<div class="grid">'
    || pgv.input('date_debut', 'date', pgv.t('planning.field_date_debut') || ' *', COALESCE(v.date_debut::text, current_date::text), true)
    || pgv.input('date_fin', 'date', pgv.t('planning.field_date_fin') || ' *', COALESCE(v.date_fin::text, current_date::text), true)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('heure_debut', 'time', pgv.t('planning.field_heure_debut'), COALESCE(v.heure_debut::text, '08:00'))
    || pgv.input('heure_fin', 'time', pgv.t('planning.field_heure_fin'), COALESCE(v.heure_fin::text, '17:00'))
    || '</div>'
    || pgv.input('lieu', 'text', pgv.t('planning.field_lieu'), v.lieu)
    || pgv.select_search('chantier_id', pgv.t('planning.field_chantier'), 'chantier_options', 'Rechercher un chantier...', v.chantier_id::text)
    || pgv.textarea('notes', pgv.t('planning.field_notes'), v.notes)
    || '<button type="submit">' || pgv.t('planning.btn_enregistrer') || '</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
