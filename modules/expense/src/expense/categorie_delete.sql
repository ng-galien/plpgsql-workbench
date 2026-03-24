CREATE OR REPLACE FUNCTION expense.categorie_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result expense.categorie;
BEGIN
  DELETE FROM expense.categorie WHERE id = p_id::int
  RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
