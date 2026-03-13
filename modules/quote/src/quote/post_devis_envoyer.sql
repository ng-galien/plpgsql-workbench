CREATE OR REPLACE FUNCTION quote.post_devis_envoyer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_statut text;
BEGIN
  SELECT statut INTO v_statut FROM quote.devis WHERE id = v_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_devis'); END IF;
  IF v_statut <> 'brouillon' THEN RAISE EXCEPTION 'Transition invalide: % -> envoye', v_statut; END IF;

  UPDATE quote.devis SET statut = 'envoye' WHERE id = v_id;

  RETURN pgv.toast(pgv.t('quote.toast_devis_sent'))
    || pgv.redirect(pgv.call_ref('get_devis', jsonb_build_object('p_id', v_id)));
END;
$function$;
