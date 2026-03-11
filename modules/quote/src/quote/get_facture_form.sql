CREATE OR REPLACE FUNCTION quote.get_facture_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_body text;
  f record;
  v_objet text := '';
  v_notes text := '';
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO f FROM quote.facture WHERE id = p_id;
    IF NOT FOUND THEN RETURN pgv.empty('Facture introuvable'); END IF;
    IF f.statut <> 'brouillon' THEN
      RETURN pgv.empty('Modification impossible', 'Seuls les brouillons sont modifiables.');
    END IF;
    v_objet := pgv.esc(f.objet);
    v_notes := pgv.esc(f.notes);
  END IF;

  v_body := pgv.breadcrumb(VARIADIC ARRAY[
    'Factures', pgv.call_ref('get_facture'),
    CASE WHEN p_id IS NOT NULL THEN 'Modifier' ELSE 'Nouvelle facture' END
  ]);

  v_body := v_body || '<form data-rpc="post_facture_save">';
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
      'value="' || f.client_id || '">',
      'value="' || f.client_id || '" selected>');
  END IF;

  v_body := v_body
    || '<label>Objet <input type="text" name="objet" value="' || v_objet || '" required></label>'
    || '<label>Notes <textarea name="notes">' || v_notes || '</textarea></label>'
    || '<button type="submit">' || CASE WHEN p_id IS NOT NULL THEN 'Mettre à jour' ELSE 'Créer la facture' END || '</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
