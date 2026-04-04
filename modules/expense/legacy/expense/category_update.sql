CREATE OR REPLACE FUNCTION expense.category_update(p_row expense.category)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_result expense.category;
BEGIN
  UPDATE expense.category SET name = COALESCE(p_row.name, name), accounting_code = COALESCE(p_row.accounting_code, accounting_code)
  WHERE id = p_row.id RETURNING * INTO v_result;
  RETURN to_jsonb(v_result);
END;
$function$;
