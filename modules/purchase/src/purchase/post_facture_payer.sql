CREATE OR REPLACE FUNCTION purchase.post_facture_payer(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
BEGIN
  UPDATE purchase.facture_fournisseur SET statut = 'payee'
   WHERE id = v_id AND statut = 'validee';

  IF NOT FOUND THEN
    RETURN pgv.toast(pgv.t('purchase.err_facture_not_validated'), 'error');
  END IF;

  RETURN pgv.toast(pgv.t('purchase.toast_facture_payee'))
    || pgv.redirect(pgv.call_ref('get_facture_fournisseur', jsonb_build_object('p_id', v_id)));
END;
$function$;
