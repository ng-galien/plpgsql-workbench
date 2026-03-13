CREATE OR REPLACE FUNCTION quote.post_devis_accepter(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_statut text;
BEGIN
  SELECT statut INTO v_statut FROM quote.devis WHERE id = v_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_devis'); END IF;
  IF v_statut <> 'envoye' THEN RAISE EXCEPTION 'Transition invalide: % -> accepte', v_statut; END IF;

  UPDATE quote.devis SET statut = 'accepte' WHERE id = v_id;

  RETURN pgv.toast(pgv.t('quote.toast_devis_accepted'))
    || pgv.redirect(pgv.call_ref('get_devis', jsonb_build_object('p_id', v_id)));
END;
$function$;
