CREATE OR REPLACE FUNCTION stock.depot_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN (
    SELECT to_jsonb(d) || jsonb_build_object(
      'nb_articles', (SELECT count(DISTINCT m.article_id) FROM stock.mouvement m WHERE m.depot_id = d.id)::int
    )
    FROM stock.depot d
    WHERE d.id = p_id::int AND d.tenant_id = current_setting('app.tenant_id', true)
  );
END;
$function$;
