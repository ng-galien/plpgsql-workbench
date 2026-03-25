CREATE OR REPLACE FUNCTION quote.post_facture_supprimer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'id')::int;
  v_statut text;
BEGIN
  SELECT statut INTO v_statut FROM quote.facture WHERE id = v_id;
  IF v_statut IS NULL THEN RAISE EXCEPTION '%', pgv.t('quote.err_not_found_facture'); END IF;
  IF v_statut <> 'brouillon' THEN RAISE EXCEPTION '%', pgv.t('quote.err_draft_delete_only'); END IF;

  DELETE FROM quote.facture WHERE id = v_id;

  RETURN pgv.toast(pgv.t('quote.toast_facture_deleted'))
    || pgv.redirect(pgv.call_ref('get_facture'));
END;
$function$;
