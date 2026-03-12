CREATE OR REPLACE FUNCTION purchase.post_ligne_supprimer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_ligne_id int := (p_data->>'p_ligne_id')::int;
  v_commande_id int;
  v_statut text;
BEGIN
  SELECT l.commande_id, c.statut INTO v_commande_id, v_statut
    FROM purchase.ligne l
    JOIN purchase.commande c ON c.id = l.commande_id
   WHERE l.id = v_ligne_id;

  IF v_statut IS NULL OR v_statut <> 'brouillon' THEN
    RETURN '<template data-toast="error">Lignes modifiables uniquement sur brouillon</template>';
  END IF;

  DELETE FROM purchase.ligne WHERE id = v_ligne_id;

  RETURN format('<template data-toast="success">Ligne supprimée</template><template data-redirect="%s"></template>',
    pgv.call_ref('get_commande', jsonb_build_object('p_id', v_commande_id)));
END;
$function$;
