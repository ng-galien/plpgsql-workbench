CREATE OR REPLACE FUNCTION stock.article_create(p_row stock.article)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.tenant_id := current_setting('app.tenant_id', true);
  p_row.created_at := now();
  p_row.updated_at := now();

  INSERT INTO stock.article (tenant_id, reference, designation, categorie, unite, prix_achat, pmp, seuil_mini, fournisseur_id, notes, active, created_at, updated_at, catalog_article_id)
  VALUES (p_row.tenant_id, p_row.reference, p_row.designation, p_row.categorie, coalesce(p_row.unite, 'u'), p_row.prix_achat, coalesce(p_row.pmp, 0), coalesce(p_row.seuil_mini, 0), p_row.fournisseur_id, coalesce(p_row.notes, ''), coalesce(p_row.active, true), p_row.created_at, p_row.updated_at, p_row.catalog_article_id)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
