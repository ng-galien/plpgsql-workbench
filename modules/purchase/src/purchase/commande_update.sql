CREATE OR REPLACE FUNCTION purchase.commande_update(p_row purchase.commande)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE purchase.commande SET
    fournisseur_id = coalesce(p_row.fournisseur_id, fournisseur_id),
    objet = coalesce(nullif(p_row.objet, ''), objet),
    notes = coalesce(p_row.notes, notes),
    date_livraison = coalesce(p_row.date_livraison, date_livraison),
    conditions_paiement = coalesce(p_row.conditions_paiement, conditions_paiement),
    updated_at = now()
  WHERE id = p_row.id
    AND tenant_id = current_setting('app.tenant_id', true)
    AND statut = 'brouillon'
  RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
