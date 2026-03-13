CREATE OR REPLACE FUNCTION planning._evenement_form_inputs(p_id integer DEFAULT NULL::integer, p_titre text DEFAULT NULL::text, p_type text DEFAULT NULL::text, p_date_debut date DEFAULT NULL::date, p_date_fin date DEFAULT NULL::date, p_heure_debut time without time zone DEFAULT NULL::time without time zone, p_heure_fin time without time zone DEFAULT NULL::time without time zone, p_lieu text DEFAULT NULL::text, p_chantier_id integer DEFAULT NULL::integer, p_notes text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN format('<input type="hidden" name="id" value="%s">', COALESCE(p_id::text, ''))
    || pgv.input('titre', 'text', pgv.t('planning.field_titre') || ' *', p_titre, true)
    || pgv.sel('type', pgv.t('planning.field_type'), jsonb_build_array(
         jsonb_build_object('label', pgv.t('planning.type_chantier'), 'value', 'chantier'),
         jsonb_build_object('label', pgv.t('planning.type_livraison'), 'value', 'livraison'),
         jsonb_build_object('label', pgv.t('planning.type_reunion'), 'value', 'reunion'),
         jsonb_build_object('label', pgv.t('planning.type_conge'), 'value', 'conge'),
         jsonb_build_object('label', pgv.t('planning.type_autre'), 'value', 'autre')
       ), COALESCE(p_type, 'chantier'))
    || '<div class="grid">'
    || pgv.input('date_debut', 'date', pgv.t('planning.field_date_debut') || ' *', COALESCE(p_date_debut::text, current_date::text), true)
    || pgv.input('date_fin', 'date', pgv.t('planning.field_date_fin') || ' *', COALESCE(p_date_fin::text, current_date::text), true)
    || '</div>'
    || '<div class="grid">'
    || pgv.input('heure_debut', 'time', pgv.t('planning.field_heure_debut'), COALESCE(p_heure_debut::text, '08:00'))
    || pgv.input('heure_fin', 'time', pgv.t('planning.field_heure_fin'), COALESCE(p_heure_fin::text, '17:00'))
    || '</div>'
    || pgv.input('lieu', 'text', pgv.t('planning.field_lieu'), p_lieu)
    || pgv.select_search('chantier_id', pgv.t('planning.field_chantier'), 'chantier_options', 'Rechercher un chantier...', p_chantier_id::text)
    || pgv.textarea('notes', pgv.t('planning.field_notes'), p_notes);
END;
$function$;
