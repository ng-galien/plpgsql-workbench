CREATE OR REPLACE FUNCTION purchase.commande_create(p_row purchase.commande)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO purchase.commande (tenant_id, numero, fournisseur_id, objet, notes, date_livraison, conditions_paiement)
  VALUES (
    current_setting('app.tenant_id', true),
    purchase._next_numero('CMD'),
    p_row.fournisseur_id,
    p_row.objet,
    coalesce(p_row.notes, ''),
    p_row.date_livraison,
    coalesce(p_row.conditions_paiement, '')
  )
  RETURNING * INTO p_row;
  RETURN to_jsonb(p_row);
END;
$function$;
