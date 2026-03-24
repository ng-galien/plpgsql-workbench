CREATE OR REPLACE FUNCTION purchase.commande_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(c) || jsonb_build_object('fournisseur_name', cl.name, 'total_ttc', purchase._total_ttc(c.id))
      FROM purchase.commande c
      JOIN crm.client cl ON cl.id = c.fournisseur_id
      WHERE c.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY c.created_at DESC;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(c) || jsonb_build_object(''fournisseur_name'', cl.name, ''total_ttc'', purchase._total_ttc(c.id))
       FROM purchase.commande c
       JOIN crm.client cl ON cl.id = c.fournisseur_id
       WHERE c.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
       || ' AND ' || pgv.rsql_to_where(p_filter, 'purchase', 'commande')
       || ' ORDER BY c.created_at DESC';
  END IF;
END;
$function$;
