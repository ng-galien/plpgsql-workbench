CREATE OR REPLACE FUNCTION purchase.post_commande_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
  v_fournisseur_id int := (p_data->>'p_fournisseur_id')::int;
  v_objet text := p_data->>'p_objet';
  v_notes text := coalesce(p_data->>'p_notes', '');
  v_date_livraison date := (p_data->>'p_date_livraison')::date;
  v_conditions text := coalesce(p_data->>'p_conditions_paiement', '');
BEGIN
  IF v_id IS NOT NULL THEN
    UPDATE purchase.commande
       SET fournisseur_id = v_fournisseur_id,
           objet = v_objet,
           notes = v_notes,
           date_livraison = v_date_livraison,
           conditions_paiement = v_conditions
     WHERE id = v_id AND statut = 'brouillon';

    IF NOT FOUND THEN
      RETURN '<template data-toast="error">Commande introuvable ou non modifiable</template>';
    END IF;

    RETURN format('<template data-toast="success">Commande mise à jour</template><template data-redirect="%s"></template>',
      pgv.call_ref('get_commande', jsonb_build_object('p_id', v_id)));
  ELSE
    INSERT INTO purchase.commande (numero, fournisseur_id, objet, notes, date_livraison, conditions_paiement)
    VALUES (purchase._next_numero('CMD'), v_fournisseur_id, v_objet, v_notes, v_date_livraison, v_conditions)
    RETURNING id INTO v_id;

    RETURN format('<template data-toast="success">Commande créée</template><template data-redirect="%s"></template>',
      pgv.call_ref('get_commande', jsonb_build_object('p_id', v_id)));
  END IF;
END;
$function$;
