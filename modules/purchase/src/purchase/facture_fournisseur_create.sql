CREATE OR REPLACE FUNCTION purchase.facture_fournisseur_create(p_row purchase.facture_fournisseur)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO purchase.facture_fournisseur (tenant_id, commande_id, numero_fournisseur, montant_ht, montant_ttc, date_facture, date_echeance, notes)
  VALUES (
    current_setting('app.tenant_id', true),
    p_row.commande_id,
    p_row.numero_fournisseur,
    p_row.montant_ht,
    p_row.montant_ttc,
    p_row.date_facture,
    p_row.date_echeance,
    coalesce(p_row.notes, '')
  )
  RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
