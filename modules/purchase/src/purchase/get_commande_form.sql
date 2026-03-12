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

  -- Fournisseur select_search (pre-filled on edit)
  DECLARE
    v_fournisseur_name text;
  BEGIN
    IF p_id IS NOT NULL THEN
      SELECT name INTO v_fournisseur_name FROM crm.client WHERE id = v_cmd.fournisseur_id;
    END IF;
    v_body := v_body
      || pgv.select_search('p_fournisseur_id', 'Fournisseur',
           'fournisseur_options', 'Rechercher un fournisseur...',
           CASE WHEN p_id IS NOT NULL THEN v_cmd.fournisseur_id::text END,
           v_fournisseur_name);
  END;

  v_body := v_body
    || format('<label>Objet<input type="text" name="p_objet" value="%s" required></label>',
       coalesce(pgv.esc(v_cmd.objet), ''))
    || format('<label>Date livraison prévue<input type="date" name="p_date_livraison" value="%s"></label>',
       coalesce(v_cmd.date_livraison::text, ''))
    || format('<label>Conditions paiement<input type="text" name="p_conditions_paiement" value="%s" placeholder="ex: 30j fin de mois"></label>',
       coalesce(pgv.esc(v_cmd.conditions_paiement), ''))
    || format('<label>Notes<textarea name="p_notes">%s</textarea></label>',
       coalesce(pgv.esc(v_cmd.notes), ''))
    || '<button type="submit">Enregistrer</button>'
    || '</form>';

  RETURN v_body;
END;
$function$;
