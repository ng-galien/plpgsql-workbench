CREATE OR REPLACE FUNCTION catalog.categorie_create(p_row catalog.categorie)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  p_row.ordre := COALESCE(p_row.ordre, 0);
  p_row.created_at := now();

  INSERT INTO catalog.categorie (nom, parent_id, ordre, created_at)
  VALUES (p_row.nom, p_row.parent_id, p_row.ordre, p_row.created_at)
  RETURNING * INTO p_row;

  RETURN to_jsonb(p_row);
END;
$function$;
