CREATE OR REPLACE FUNCTION quote.get_devis_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  d record;
  v_objet text := '';
  v_validite int := 30;
  v_notes text := '';
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO d FROM quote.devis WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty('Devis introuvable'); END IF;
    IF d.statut <> 'brouillon' THEN
      RETURN pgv.empty('Modification impossible', 'Seuls les brouillons sont modifiables.');
    END IF;
    v_objet := pgv.esc(d.objet);
    v_validite := d.validite_jours;
    v_notes := pgv.esc(d.notes);
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    'Devis', pgv.call_ref('get_devis'),
    CASE WHEN p_id IS NOT NULL THEN 'Modifier' ELSE 'Nouveau devis' END
  ]);

  v_body := v_body || '<form data-rpc="post_devis_save">';
  IF p_id IS NOT NULL THEN
    v_body := v_body || '<input type="hidden" name="id" value="' || p_id || '">';
  END IF;

  v_body := v_body
    || '<label>Client <select name="client_id" required>'
    || '<option value="">— Choisir —</option>'
    || quote._client_options()
    || '</select></label>';

  IF p_id IS NOT NULL THEN
    v_body := replace(v_body,
      'value="' || d.client_id || '">',
      'value="' || d.client_id || '" selected>');
  END IF;

  v_body := v_body
    || '<label>Objet <input type="text" name="objet" value="' || v_objet || '" required></label>'
    || '<label>Validité (jours) <input type="number" name="validite_jours" value="' || v_validite || '" min="1"></label>'
    || '<label>Notes <textarea name="notes">' || v_notes || '</textarea></label>'
    || '<button type="submit">' || CASE WHEN p_id IS NOT NULL THEN 'Mettre à jour' ELSE 'Créer le devis' END || '</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
