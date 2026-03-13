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

  v_body := pgv.form('post_evenement_save',
    planning._evenement_form_inputs(p_id, v.titre, v.type, v.date_debut, v.date_fin, v.heure_debut, v.heure_fin, v.lieu, v.chantier_id, v.notes)
  , pgv.t('planning.btn_enregistrer'));

  RETURN v_body;
END;
$function$;
