CREATE OR REPLACE FUNCTION stock.warehouse_list(p_filter text DEFAULT NULL::text)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF p_filter IS NULL THEN
    RETURN QUERY
      SELECT to_jsonb(w) || jsonb_build_object(
        'article_count', (SELECT count(DISTINCT m.article_id) FROM stock.movement m WHERE m.warehouse_id = w.id)::int
      )
      FROM stock.warehouse w
      WHERE w.tenant_id = current_setting('app.tenant_id', true)
      ORDER BY w.name;
  ELSE
    RETURN QUERY EXECUTE
      'SELECT to_jsonb(w) || jsonb_build_object(
        ''article_count'', (SELECT count(DISTINCT m.article_id) FROM stock.movement m WHERE m.warehouse_id = w.id)::int
      )
      FROM stock.warehouse w
      WHERE w.tenant_id = ' || quote_literal(current_setting('app.tenant_id', true))
      || ' AND ' || pgv.rsql_to_where(p_filter, 'stock', 'warehouse')
      || ' ORDER BY w.name';
  END IF;
END;
$function$;
