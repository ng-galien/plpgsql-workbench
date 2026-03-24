CREATE OR REPLACE FUNCTION stock.article_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(a) || jsonb_build_object(
        'fournisseur_name', c.name,
        'stock_actuel', stock._stock_actuel(a.id)
      )
      FROM stock.article a
      LEFT JOIN crm.client c ON c.id = a.fournisseur_id
      WHERE a.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY a.designation;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(a) || jsonb_build_object(
        ''fournisseur_name'', c.name,
        ''stock_actuel'', stock._stock_actuel(a.id)
      )
      FROM stock.article a
      LEFT JOIN crm.client c ON c.id = a.fournisseur_id
      WHERE a.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
      || ' AND ' || pgv.rsql_to_where(p_filter, 'stock', 'article')
      || ' ORDER BY a.designation';
  END IF;
END;
$function$;
