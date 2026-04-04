CREATE OR REPLACE FUNCTION expense.category_delete(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_result expense.category;
BEGIN
  DELETE FROM expense.category WHERE id = p_id::int RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
