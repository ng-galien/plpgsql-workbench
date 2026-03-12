CREATE OR REPLACE FUNCTION purchase.post_commande_envoyer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
BEGIN
  UPDATE purchase.commande SET statut = 'envoyee'
   WHERE id = v_id AND statut = 'brouillon';

  IF NOT FOUND THEN
    RETURN '<template data-toast="error">Commande introuvable ou déjà envoyée</template>';
  END IF;

  RETURN format('<template data-toast="success">Commande envoyée</template><template data-redirect="%s"></template>',
    pgv.call_ref('get_commande', jsonb_build_object('p_id', v_id)));
END;
$function$;
