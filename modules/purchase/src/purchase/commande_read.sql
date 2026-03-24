CREATE OR REPLACE FUNCTION purchase.commande_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN (
    SELECT to_jsonb(c) || jsonb_build_object(
      'fournisseur_name', cl.name,
      'total_ht', purchase._total_ht(c.id),
      'total_tva', purchase._total_tva(c.id),
      'total_ttc', purchase._total_ttc(c.id)
    )
    FROM purchase.commande c
    JOIN crm.client cl ON cl.id = c.fournisseur_id
    WHERE c.id = p_id::int AND c.tenant_id = current_setting('app.tenant_id', true)
  );
END;
$function$;
