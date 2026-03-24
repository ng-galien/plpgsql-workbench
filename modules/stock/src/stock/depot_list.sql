CREATE OR REPLACE FUNCTION stock.depot_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(d) || jsonb_build_object(
        'nb_articles', (SELECT count(DISTINCT m.article_id) FROM stock.mouvement m WHERE m.depot_id = d.id)::int
      )
      FROM stock.depot d
      WHERE d.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY d.nom;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(d) || jsonb_build_object(
        ''nb_articles'', (SELECT count(DISTINCT m.article_id) FROM stock.mouvement m WHERE m.depot_id = d.id)::int
      )
      FROM stock.depot d
      WHERE d.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
      || ' AND ' || pgv.rsql_to_where(p_filter, 'stock', 'depot')
      || ' ORDER BY d.nom';
  END IF;
END;
$function$;
