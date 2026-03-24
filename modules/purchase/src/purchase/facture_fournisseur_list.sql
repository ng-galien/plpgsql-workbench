CREATE OR REPLACE FUNCTION purchase.facture_fournisseur_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(f) || jsonb_build_object('commande_numero', c.numero, 'fournisseur_name', cl.name, 'fournisseur_id', cl.id)
      FROM purchase.facture_fournisseur f
      LEFT JOIN purchase.commande c ON c.id = f.commande_id
      LEFT JOIN crm.client cl ON cl.id = c.fournisseur_id
      WHERE f.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY f.created_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(f) || jsonb_build_object(''commande_numero'', c.numero, ''fournisseur_name'', cl.name, ''fournisseur_id'', cl.id)
       FROM purchase.facture_fournisseur f
       LEFT JOIN purchase.commande c ON c.id = f.commande_id
       LEFT JOIN crm.client cl ON cl.id = c.fournisseur_id
       WHERE f.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'purchase', 'facture_fournisseur')
       || ' ORDER BY f.created_at DESC';
  END IF;
END;
$function$;
