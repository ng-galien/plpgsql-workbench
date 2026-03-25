CREATE OR REPLACE FUNCTION purchase.post_facture_saisir(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int;
BEGIN
  INSERT INTO purchase.facture_fournisseur (
    commande_id, numero_fournisseur, montant_ht, montant_ttc,
    date_facture, date_echeance, notes
  ) VALUES (
    (p_data->>'p_commande_id')::int,
    p_data->>'p_numero_fournisseur',
    (p_data->>'p_montant_ht')::numeric,
    (p_data->>'p_montant_ttc')::numeric,
    (p_data->>'p_date_facture')::date,
    (p_data->>'p_date_echeance')::date,
    coalesce(p_data->>'p_notes', '')
  ) RETURNING id INTO v_id;

  RETURN pgv.toast(pgv.t('purchase.toast_facture_saisie'))
    || pgv.redirect(pgv.call_ref('get_facture_fournisseur', jsonb_build_object('p_id', v_id)));
END;
$function$;
