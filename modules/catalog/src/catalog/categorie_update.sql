CREATE OR REPLACE FUNCTION catalog.categorie_update(p_row catalog.categorie)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE catalog.categorie SET
    nom = COALESCE(p_row.nom, nom),
    parent_id = COALESCE(p_row.parent_id, parent_id),
    ordre = COALESCE(p_row.ordre, ordre)
  WHERE id = p_row.id
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
