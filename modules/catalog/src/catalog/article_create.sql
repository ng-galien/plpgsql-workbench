CREATE OR REPLACE FUNCTION catalog.article_create(p_row catalog.article)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.actif := COALESCE(p_row.actif, true);
  p_row.unite := COALESCE(p_row.unite, 'u');
  p_row.tva := COALESCE(p_row.tva, 20.00);
  p_row.created_at := now();
  p_row.updated_at := now();

  INSERT INTO catalog.article (reference, designation, description, categorie_id, unite, prix_vente, prix_achat, tva, actif, created_at, updated_at)
  VALUES (p_row.reference, p_row.designation, p_row.description, p_row.categorie_id, p_row.unite, p_row.prix_vente, p_row.prix_achat, p_row.tva, p_row.actif, p_row.created_at, p_row.updated_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
