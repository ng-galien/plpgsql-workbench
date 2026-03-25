CREATE OR REPLACE FUNCTION purchase.post_commande_annuler(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
  v_has_receptions bool;
BEGIN
  SELECT exists(SELECT 1 FROM purchase.reception WHERE commande_id = v_id) INTO v_has_receptions;

  IF v_has_receptions THEN
    RETURN pgv.toast(pgv.t('purchase.err_cancel_receptions'), 'error');
  END IF;

  UPDATE purchase.commande SET statut = 'annulee'
   WHERE id = v_id AND statut IN ('brouillon', 'envoyee');

  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('purchase.err_not_cancellable'), 'error');
  END IF;

  RETURN pgv.toast(pgv.t('purchase.toast_commande_annulee'))
    || pgv.redirect(pgv.call_ref('get_commande', jsonb_build_object('p_id', v_id)));
END;
$function$;
