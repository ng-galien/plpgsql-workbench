CREATE OR REPLACE FUNCTION project.get_chantier_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  c record;
  v_objet text := '';
  v_adresse text := '';
  v_notes text := '';
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO c FROM project.chantier WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty('Chantier introuvable'); END IF;
    IF c.statut NOT IN ('preparation', 'execution') THEN
      RETURN pgv.empty('Modification impossible', 'Seuls les chantiers en préparation ou en cours sont modifiables.');
    END IF;
    v_objet := pgv.esc(c.objet);
    v_adresse := pgv.esc(c.adresse);
    v_notes := pgv.esc(c.notes);
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    'Chantiers', pgv.call_ref('get_chantiers'),
    CASE WHEN p_id IS NOT NULL THEN 'Modifier' ELSE 'Nouveau chantier' END
  ]);

  v_body := v_body || '<form data-rpc="post_chantier_save">';
  IF p_id IS NOT NULL THEN
    v_body := v_body || '<input type="hidden" name="id" value="' || p_id || '">';
  END IF;

  v_body := v_body
    || '<label>Client <select name="client_id" required>'
    || '<option value="">— Choisir —</option>'
    || project._client_options()
    || '</select></label>';

  IF p_id IS NOT NULL THEN
    v_body := replace(v_body,
      'value="' || c.client_id || '">',
      'value="' || c.client_id || '" selected>');
  END IF;

  v_body := v_body
    || '<label>Devis lié (optionnel) <select name="devis_id">'
    || '<option value="">— Aucun —</option>'
    || project._devis_options()
    || '</select></label>';

  IF p_id IS NOT NULL AND c.devis_id IS NOT NULL THEN
    v_body := replace(v_body,
      'value="' || c.devis_id || '">',
      'value="' || c.devis_id || '" selected>');
  END IF;

  v_body := v_body
    || '<label>Objet <input type="text" name="objet" value="' || v_objet || '" required></label>'
    || '<label>Adresse <input type="text" name="adresse" value="' || v_adresse || '"></label>'
    || '<div class="grid">'
    || '<label>Date début <input type="date" name="date_debut"'
    || CASE WHEN p_id IS NOT NULL AND c.date_debut IS NOT NULL THEN ' value="' || c.date_debut::text || '"' ELSE '' END
    || '></label>'
    || '<label>Date fin prévue <input type="date" name="date_fin_prevue"'
    || CASE WHEN p_id IS NOT NULL AND c.date_fin_prevue IS NOT NULL THEN ' value="' || c.date_fin_prevue::text || '"' ELSE '' END
    || '></label>'
    || '</div>'
    || '<label>Notes <textarea name="notes">' || v_notes || '</textarea></label>'
    || '<button type="submit">' || CASE WHEN p_id IS NOT NULL THEN 'Mettre à jour' ELSE 'Créer le chantier' END || '</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
