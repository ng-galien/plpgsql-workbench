CREATE OR REPLACE FUNCTION purchase.facture_fournisseur_update(p_row purchase.facture_fournisseur)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE purchase.facture_fournisseur SET
    numero_fournisseur = coalesce(nullif(p_row.numero_fournisseur, ''), numero_fournisseur),
    commande_id = coalesce(p_row.commande_id, commande_id),
    montant_ht = coalesce(p_row.montant_ht, montant_ht),
    montant_ttc = coalesce(p_row.montant_ttc, montant_ttc),
    date_facture = coalesce(p_row.date_facture, date_facture),
    date_echeance = coalesce(p_row.date_echeance, date_echeance),
    notes = coalesce(p_row.notes, notes),
    updated_at = now()
  WHERE id = p_row.id
    AND tenant_id = current_setting('app.tenant_id', true)
    AND statut = 'recue'
  RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
