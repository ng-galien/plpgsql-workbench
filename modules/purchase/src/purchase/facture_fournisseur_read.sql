CREATE OR REPLACE FUNCTION purchase.facture_fournisseur_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN (
    SELECT to_jsonb(f) || jsonb_build_object(
      'commande_numero', c.numero,
      'fournisseur_name', cl.name,
      'fournisseur_id', cl.id,
      'commande_ttc', CASE WHEN f.commande_id IS NOT NULL THEN purchase._total_ttc(f.commande_id) END
    )
    FROM purchase.facture_fournisseur f
    LEFT JOIN purchase.commande c ON c.id = f.commande_id
    LEFT JOIN crm.client cl ON cl.id = c.fournisseur_id
    WHERE f.id = p_id::int AND f.tenant_id = current_setting('app.tenant_id', true)
  );
END;
$function$;
