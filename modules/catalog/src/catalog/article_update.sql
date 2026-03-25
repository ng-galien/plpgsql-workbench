CREATE OR REPLACE FUNCTION catalog.article_update(p_row catalog.article)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE catalog.article SET
    reference = COALESCE(p_row.reference, reference),
    designation = COALESCE(p_row.designation, designation),
    description = COALESCE(p_row.description, description),
    categorie_id = COALESCE(p_row.categorie_id, categorie_id),
    unite = COALESCE(p_row.unite, unite),
    prix_vente = COALESCE(p_row.prix_vente, prix_vente),
    prix_achat = COALESCE(p_row.prix_achat, prix_achat),
    tva = COALESCE(p_row.tva, tva),
    actif = COALESCE(p_row.actif, actif),
    updated_at = now()
  WHERE id = p_row.id
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
