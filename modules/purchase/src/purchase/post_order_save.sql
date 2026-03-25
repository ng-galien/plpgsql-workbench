CREATE OR REPLACE FUNCTION purchase.post_order_save(p_data jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id int := (p_data->>'p_id')::int;
  v_supplier_id int := (p_data->>'p_fournisseur_id')::int;
  v_subject text := p_data->>'p_objet';
  v_notes text := coalesce(p_data->>'p_notes', '');
  v_delivery_date date := (p_data->>'p_date_livraison')::date;
  v_payment_terms text := coalesce(p_data->>'p_conditions_paiement', '');
BEGIN
  IF v_id IS NOT NULL THEN
    UPDATE purchase.purchase_order
       SET supplier_id = v_supplier_id,
           subject = v_subject,
           notes = v_notes,
           delivery_date = v_delivery_date,
           payment_terms = v_payment_terms
     WHERE id = v_id AND status = 'draft';

    IF NOT FOUND THEN
      RETURN pgv.toast(pgv.t('purchase.err_order_not_found'), 'error');
    END IF;

    RETURN pgv.toast(pgv.t('purchase.toast_order_updated'))
      || pgv.redirect(pgv.call_ref('get_order', jsonb_build_object('p_id', v_id)));
  ELSE
    INSERT INTO purchase.purchase_order (number, supplier_id, subject, notes, delivery_date, payment_terms)
    VALUES (purchase._next_number('PO'), v_supplier_id, v_subject, v_notes, v_delivery_date, v_payment_terms)
    RETURNING id INTO v_id;

    RETURN pgv.toast(pgv.t('purchase.toast_order_created'))
      || pgv.redirect(pgv.call_ref('get_order', jsonb_build_object('p_id', v_id)));
  END IF;
END;
$function$;
