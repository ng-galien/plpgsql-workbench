CREATE OR REPLACE FUNCTION stock.article_update(p_row stock.article)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE stock.article SET
    reference = COALESCE(NULLIF(p_row.reference, ''), reference),
    designation = COALESCE(NULLIF(p_row.designation, ''), designation),
    categorie = COALESCE(NULLIF(p_row.categorie, ''), categorie),
    unite = COALESCE(NULLIF(p_row.unite, ''), unite),
    prix_achat = COALESCE(p_row.prix_achat, prix_achat),
    seuil_mini = COALESCE(p_row.seuil_mini, seuil_mini),
    fournisseur_id = COALESCE(p_row.fournisseur_id, fournisseur_id),
    notes = COALESCE(p_row.notes, notes),
    active = COALESCE(p_row.active, active),
    catalog_article_id = COALESCE(p_row.catalog_article_id, catalog_article_id),
    updated_at = now()
  WHERE id = p_row.id AND tenant_id = current_setting('app.tenant_id', true)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
