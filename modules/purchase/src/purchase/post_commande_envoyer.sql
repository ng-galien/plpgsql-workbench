CREATE OR REPLACE FUNCTION purchase.post_commande_envoyer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
BEGIN
  UPDATE purchase.commande SET statut = 'envoyee'
   WHERE id = v_id AND statut = 'brouillon';

  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('purchase.err_already_sent'), 'error');
  END IF;

  RETURN pgv.toast(pgv.t('purchase.toast_commande_envoyee'))
    || pgv.redirect(pgv.call_ref('get_commande', jsonb_build_object('p_id', v_id)));
END;
$function$;
