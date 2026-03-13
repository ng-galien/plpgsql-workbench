CREATE OR REPLACE FUNCTION project._chantier_form_fields(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  c record;
  v_body text := '';
  v_objet text := '';
  v_adresse text := '';
  v_notes text := '';
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO c FROM project.chantier WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty(pgv.t('project.empty_introuvable')); END IF;
    v_body := '<input type="hidden" name="id" value="' || p_id || '">';
    v_objet := pgv.esc(c.objet);
    v_adresse := pgv.esc(c.adresse);
    v_notes := pgv.esc(c.notes);
  END IF;

  v_body := v_body
    || '<label>' || pgv.t('project.field_client') || ' <select name="client_id" required>'
    || '<option value="">' || pgv.t('project.field_choisir') || '</option>'
    || project._client_options()
    || '</select></label>';

  IF p_id IS NOT NULL THEN
    v_body := replace(v_body,
      'value="' || c.client_id || '">',
      'value="' || c.client_id || '" selected>');
  END IF;

  v_body := v_body
    || '<label>' || pgv.t('project.field_devis') || ' <select name="devis_id">'
    || '<option value="">' || pgv.t('project.field_aucun') || '</option>'
    || project._devis_options()
    || '</select></label>';

  IF p_id IS NOT NULL AND c.devis_id IS NOT NULL THEN
    v_body := replace(v_body,
      'value="' || c.devis_id || '">',
      'value="' || c.devis_id || '" selected>');
  END IF;

  v_body := v_body
    || pgv.input('objet', 'text', pgv.t('project.field_objet'), v_objet, true)
    || pgv.input('adresse', 'text', pgv.t('project.field_adresse'), v_adresse)
    || '<div class="grid">'
    || pgv.input('date_debut', 'date', pgv.t('project.field_date_debut'),
         CASE WHEN p_id IS NOT NULL AND c.date_debut IS NOT NULL THEN c.date_debut::text END)
    || pgv.input('date_fin_prevue', 'date', pgv.t('project.field_date_fin_prevue'),
         CASE WHEN p_id IS NOT NULL AND c.date_fin_prevue IS NOT NULL THEN c.date_fin_prevue::text END)
    || '</div>'
    || pgv.textarea('notes', pgv.t('project.field_notes'), v_notes);

  RETURN v_body;
END;
$function$;
