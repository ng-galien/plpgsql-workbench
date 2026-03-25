CREATE OR REPLACE FUNCTION expense.categorie_update(p_row expense.categorie)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_result expense.categorie;
BEGIN
  UPDATE expense.categorie SET
    nom = COALESCE(p_row.nom, nom),
    code_comptable = COALESCE(p_row.code_comptable, code_comptable)
  WHERE id = p_row.id
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
