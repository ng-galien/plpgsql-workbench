CREATE OR REPLACE FUNCTION expense.categorie_create(p_row expense.categorie)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result expense.categorie;
BEGIN
  INSERT INTO expense.categorie (nom, code_comptable)
  VALUES (p_row.nom, p_row.code_comptable)
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
