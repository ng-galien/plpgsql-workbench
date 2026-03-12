CREATE OR REPLACE FUNCTION purchase.post_commande_annuler(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
  v_has_receptions bool;
BEGIN
  SELECT exists(SELECT 1 FROM purchase.reception WHERE commande_id = v_id) INTO v_has_receptions;

  IF v_has_receptions THEN
    RETURN '<template data-toast="error">Impossible d''annuler : des réceptions existent</template>';
  END IF;

  UPDATE purchase.commande SET statut = 'annulee'
   WHERE id = v_id AND statut IN ('brouillon', 'envoyee');

  IF NOT FOUND THEN
    RETURN '<template data-toast="error">Commande introuvable ou non annulable</template>';
  END IF;

  RETURN format('<template data-toast="success">Commande annulée</template><template data-redirect="%s"></template>',
    pgv.call_ref('get_commande', jsonb_build_object('p_id', v_id)));
END;
$function$;
