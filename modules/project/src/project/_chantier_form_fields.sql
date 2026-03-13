CREATE OR REPLACE FUNCTION project._chantier_form_fields(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text := '';
  v_objet text := '';
  v_adresse text := '';
  v_notes text := '';
  v_date_debut text := '';
  v_date_fin text := '';
  v_client_id int;
  v_devis_id int;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT objet, adresse, notes, date_debut::text, date_fin_prevue::text, client_id, devis_id
      INTO v_objet, v_adresse, v_notes, v_date_debut, v_date_fin, v_client_id, v_devis_id
      FROM project.chantier WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty(pgv.t('project.empty_introuvable')); END IF;
    v_body := '<input type="hidden" name="id" value="' || p_id || '">';
    v_objet := pgv.esc(v_objet);
    v_adresse := pgv.esc(COALESCE(v_adresse, ''));
    v_notes := pgv.esc(COALESCE(v_notes, ''));
    v_date_debut := COALESCE(v_date_debut, '');
    v_date_fin := COALESCE(v_date_fin, '');
  END IF;

  v_body := v_body
    || '<label>' || pgv.t('project.field_client') || ' <select name="client_id" required>'
    || '<option value="">' || pgv.t('project.field_choisir') || '</option>'
    || project._client_options()
    || '</select></label>';

  IF v_client_id IS NOT NULL THEN
    v_body := replace(v_body,
      'value="' || v_client_id || '">',
      'value="' || v_client_id || '" selected>');
  END IF;

  v_body := v_body
    || '<label>' || pgv.t('project.field_devis') || ' <select name="devis_id">'
    || '<option value="">' || pgv.t('project.field_aucun') || '</option>'
    || project._devis_options()
    || '</select></label>';

  IF v_devis_id IS NOT NULL THEN
    v_body := replace(v_body,
      'value="' || v_devis_id || '">',
      'value="' || v_devis_id || '" selected>');
  END IF;

  v_body := v_body
    || pgv.input('objet', 'text', pgv.t('project.field_objet'), v_objet, true)
    || pgv.input('adresse', 'text', pgv.t('project.field_adresse'), v_adresse)
    || '<div class="grid">'
    || pgv.input('date_debut', 'date', pgv.t('project.field_date_debut'), NULLIF(v_date_debut, ''))
    || pgv.input('date_fin_prevue', 'date', pgv.t('project.field_date_fin_prevue'), NULLIF(v_date_fin, ''))
    || '</div>'
    || pgv.textarea('notes', pgv.t('project.field_notes'), v_notes);

  RETURN v_body;
END;
$function$;
