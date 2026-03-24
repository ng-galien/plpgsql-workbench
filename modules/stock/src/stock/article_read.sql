CREATE OR REPLACE FUNCTION stock.article_read(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN (
    SELECT to_jsonb(a) || jsonb_build_object(
      'fournisseur_name', c.name,
      'stock_actuel', stock._stock_actuel(a.id)
    )
    FROM stock.article a
    LEFT JOIN crm.client c ON c.id = a.fournisseur_id
    WHERE a.id = p_id::int AND a.tenant_id = current_setting('app.tenant_id', true)
  );
END;
$function$;
