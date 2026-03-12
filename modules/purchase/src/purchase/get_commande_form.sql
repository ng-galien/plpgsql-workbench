CREATE OR REPLACE FUNCTION purchase.get_commande_form(p_id integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_cmd purchase.commande;
  v_title text;
  v_body text;
BEGIN
  IF p_id IS NOT NULL THEN
    SELECT * INTO v_cmd FROM purchase.commande WHERE id = p_id;
    v_title := 'Modifier commande ' || v_cmd.numero;
  ELSE
    v_title := 'Nouvelle commande';
  END IF;

  v_body := '<h3>' || pgv.esc(v_title) || '</h3>'
    || '<form data-rpc="post_commande_save">';

  IF p_id IS NOT NULL THEN
    v_body := v_body || format('<input type="hidden" name="p_id" value="%s">', p_id);
  END IF;

  v_body := v_body
    || '<label>Fournisseur<select name="p_fournisseur_id" required>'
    || purchase._fournisseur_options()
    || '</select></label>';

  -- Pre-select if editing
  IF p_id IS NOT NULL THEN
    v_body := replace(v_body,
      format('value="%s">', v_cmd.fournisseur_id),
      format('value="%s" selected>', v_cmd.fournisseur_id));
  END IF;

  v_body := v_body
    || format('<label>Objet<input type="text" name="p_objet" value="%s" required></label>',
       coalesce(pgv.esc(v_cmd.objet), ''))
    || format('<label>Date livraison prévue<input type="date" name="p_date_livraison" value="%s"></label>',
       coalesce(v_cmd.date_livraison::text, ''))
    || format('<label>Notes<textarea name="p_notes">%s</textarea></label>',
       coalesce(pgv.esc(v_cmd.notes), ''))
    || '<button type="submit">Enregistrer</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
