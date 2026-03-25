CREATE OR REPLACE FUNCTION purchase.post_invoice_create(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int;
BEGIN
  INSERT INTO purchase.supplier_invoice (
    order_id, supplier_ref, amount_excl_tax, amount_incl_tax,
    invoice_date, due_date, notes
  ) VALUES (
    (p_data->>'p_commande_id')::int,
    p_data->>'p_numero_fournisseur',
    (p_data->>'p_montant_ht')::numeric,
    (p_data->>'p_montant_ttc')::numeric,
    (p_data->>'p_date_facture')::date,
    (p_data->>'p_date_echeance')::date,
    coalesce(p_data->>'p_notes', '')
  ) RETURNING id INTO v_id;

  RETURN pgv.toast(pgv.t('purchase.toast_invoice_created'))
    || pgv.redirect(pgv.call_ref('get_supplier_invoice', jsonb_build_object('p_id', v_id)));
END;
$function$;
